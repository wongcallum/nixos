{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixpkgs.shama = "unstable";

  flake.modules.nixos."hosts/nixos/shama" =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      repairWindowsBootloader = pkgs.writeShellScript "shama-repair-windows-bootloader" ''
        set -euo pipefail

        windowsLoader=${config.boot.loader.efi.efiSysMountPoint}/EFI/Microsoft/Boot/bootmgfw.efi
        windowsBackup=${config.boot.loader.efi.efiSysMountPoint}/EFI/NixOS/Windows.efi
        legacyWindowsBackup=${config.boot.loader.efi.efiSysMountPoint}/EFI/Microsoft/Boot/bootmgfw.windows.efi
        limineLoader=${config.boot.loader.efi.efiSysMountPoint}/EFI/limine/BOOTX64.EFI

        if [[ ! -e "$limineLoader" ]]; then
          echo "refusing to repair the Microsoft boot path: Limine is not installed" >&2
          exit 1
        fi

        # Keep the Windows loader outside EFI/Microsoft/Boot. Windows servicing
        # is allowed to replace or clean that directory, but must not be able
        # to destroy the only Windows loader we can chainload from Limine.
        if [[ ! -e "$windowsBackup" ]]; then
          if [[ -e "$legacyWindowsBackup" ]]; then
            ${pkgs.coreutils}/bin/install -D -m 0600 "$legacyWindowsBackup" "$windowsBackup"
          elif [[ ! -e "$windowsLoader" ]]; then
            echo "refusing to install Limine at the Microsoft path: Windows bootloader is missing" >&2
            exit 1
          elif ${pkgs.diffutils}/bin/cmp --silent "$limineLoader" "$windowsLoader"; then
            echo "refusing to install Limine at the Microsoft path: Windows bootloader backup is missing" >&2
            exit 1
          else
            ${pkgs.coreutils}/bin/install -D -m 0600 "$windowsLoader" "$windowsBackup"
          fi
        fi

        if ${pkgs.diffutils}/bin/cmp --silent "$limineLoader" "$windowsBackup"; then
          echo "refusing to install Limine at the Microsoft path: Windows backup is not a Windows loader" >&2
          exit 1
        fi

        ${pkgs.coreutils}/bin/install -D -m 0600 "$limineLoader" "$windowsLoader"
      '';
    in

    {
      imports = [
        ./_disko.nix
        ./_packages.nix

        inputs.chaotic.nixosModules.default
        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        limine
        impermanence-btrfs
        callum
        desktop
        syncthing-desktop
        laptop
        autofs
        nix-monitored
        freesmlauncher
        libvirt
        docker
        keyd
        bluetooth
      ]);

      system.stateVersion = "26.05";

      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "iHD";

        # needed for openvino npu device
        ZE_ENABLE_ALT_DRIVERS = "/run/opengl-driver/lib/libze_intel_npu.so.1";
      };

      networking.networkmanager.enable = true;
      services.resolved.enable = true;

      modules = {
        limine.rememberLastEntry = true;
        syncthing-desktop.user = "callum";
        firefox.transparency = {
          enableToolbox = true;
          enablePage = false;
        };
      };

      users.users.callum.extraGroups = [
        "networkmanager"
        "adbusers"
      ];

      boot = {
        # Clang ThinLTO + BORE scheduler, optimized for this CPU.
        kernelPackages = pkgs.linuxPackages_cachyos.cachyOverride {
          cachyVars = pkgs.linuxPackages_cachyos.kernel.cachyConfig.cachyVars // {
            _processor_opt = "GENERIC_V3";
            _tickrate = "idle";
            _hugepage = "madvise";
          };
        };
        kernelModules = [
          "kvm-intel"
          "uinput"
          "ntsync"
        ];

        kernelPatches = [
          {
            name = "cs35l41-omnibook7-8e3b";
            patch = pkgs.fetchpatch {
              url = "https://lore.kernel.org/linux-sound/0108019f32ada4d0-8ff2c576-8eb9-4ac4-803e-8ff4e1ce57d3-000000@ap-southeast-2.amazonses.com/raw";
              hash = "sha256-oN9tNA0jeRLel1Rv8gjjNc7iLTBTaYxTZ8ibRhuEjCI=";
            };
          }
          {
            name = "alc245-omnibook7-8e3b";
            patch = pkgs.fetchpatch {
              url = "https://lore.kernel.org/linux-sound/0108019f32adb483-2c606373-6a9f-483c-ba13-c413bc432170-000000@ap-southeast-2.amazonses.com/raw";
              hash = "sha256-VnzxUqQZGyTrkLcGXCU7/6xPLz/U4Pf9svUu1upNcF8=";
            };
          }
        ];

        initrd = {
          availableKernelModules = [
            "nvme"
            "xhci_pci"
            "thunderbolt"
            "usb_storage"
            "usbhid"
            "sd_mod"
          ];

          systemd.services.impermanence-root-rollback.after = [
            "systemd-hibernate-resume.service"
          ];
        };

        # This HP firmware ignores non-Microsoft boot entries whenever Windows is
        # installed. Keep the genuine Windows loader outside the Microsoft tree,
        # point Limine at it, and reinstall Limine at the path the firmware starts.
        loader.limine = {
          # HP firmware is deliberately targeted through the Microsoft path
          # below; do not switch this to EFI/BOOT/BOOTX64.EFI implicitly.
          efiInstallAsRemovable = false;

          extraEntries = ''
            /Windows
                protocol: efi
                path: boot():///EFI/NixOS/Windows.efi
          '';

          extraInstallCommands = "${repairWindowsBootloader}";
        };

        # allow limine to take over the world
        loader.efi.canTouchEfiVariables = true;
      };
      # Windows can restore its loader at the Microsoft path while servicing
      # itself. Repair it on every NixOS boot before the next reboot.
      systemd.services.shama-limine-windows-bootloader = {
        description = "Keep Limine at the HP firmware boot path";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        unitConfig.RequiresMountsFor = "/boot";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = repairWindowsBootloader;
          RemainAfterExit = true;
        };
      };

      # backup kernel
      specialisation.LinuxLatest.configuration = {
        boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
        # Keep the fallback kernel unpatched.
        boot.kernelPatches = lib.mkForce [ ];
      };

      hardware = {
        enableRedistributableFirmware = true;
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        cpu.intel.npu.enable = true;

        graphics = {
          enable = true;
          # for some games
          enable32Bit = true;
          extraPackages = with pkgs; [
            intel-media-driver
            vpl-gpu-rt
          ];
        };
      };
    };
}
