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
    {
      imports = [
        ./_disko.nix
        ./_packages.nix

        inputs.chaotic.nixosModules.default
        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        limine
        console-font
        zram

        callum
        tailscale
        autofs
        cryptomatord
        zed
        disk-utils
        nix-monitored
        nix-discord-rpc

        impermanence-btrfs

        audio
        desktop
        niri
        plasma
        keyd
        libvirt
        docker
        fonts
        bluetooth
        firefox
        ghostty
        thunderbird
        laptop
        nix-ld
        syncthing-desktop
        direnv
        zoxide
        helium
        trilium-desktop
      ]);

      system.stateVersion = "26.05";

      environment.variables = {
        EDITOR = "nvim";
        GOPATH = "/home/callum/.local/share/go";
        GOBIN = "/home/callum/.local/bin";
      };

      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "iHD";

        # needed for openvino npu device
        ZE_ENABLE_ALT_DRIVERS = "/run/opengl-driver/lib/libze_intel_npu.so.1";
      };

      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [
        (final: prev: {
          nnn = prev.nnn.overrideAttrs {
            version = "5.3-unstable-2026-05-29";
            src = final.fetchFromGitHub {
              owner = "jarun";
              repo = "nnn";
              rev = "2f1d36273ac256723781be82088d6f95edbbe2e5";
              sha256 = "sha256-u77QZOlzLZ4CDjZmuGnyEF9avOoMbLxnRO7M2JHTb1g=";
            };
          };
        })
      ];

      networking.networkmanager.enable = true;
      services.resolved.enable = true;
      documentation.man.cache.enable = false;

      modules = {
        syncthing-desktop.user = "callum";
        laptop.suspendThenHibernate.enable = true;
        firefox.transparency = {
          enableToolbox = true;
          enablePage = true;
        };
      };

      users.users.callum.extraGroups = [
        "networkmanager"
        "adbusers"
      ];

      # NixOS automatically creates with `btrfs filesystem mkswapfile`
      # priority is automatically set below zram
      swapDevices = [
        {
          device = "/persist/swapfile";
          size = 32 * 1024; # MiB
        }
      ];

      boot = {
        # LTO+BORE kernel
        kernelPackages = pkgs.linuxPackages_cachyos;
        kernelModules = [
          "kvm-intel"
          "uinput"
        ];

        # kernelPatches = [
        #   {
        #     name = "cs35l41-omnibook7-8e3b";
        #     patch = pkgs.fetchpatch {
        #       url = "https://lore.kernel.org/linux-sound/0108019f32ada4d0-8ff2c576-8eb9-4ac4-803e-8ff4e1ce57d3-000000@ap-southeast-2.amazonses.com/raw";
        #       hash = "sha256-oN9tNA0jeRLel1Rv8gjjNc7iLTBTaYxTZ8ibRhuEjCI=";
        #     };
        #   }
        #   {
        #     name = "alc245-omnibook7-8e3b";
        #     patch = pkgs.fetchpatch {
        #       url = "https://lore.kernel.org/linux-sound/0108019f32adb483-2c606373-6a9f-483c-ba13-c413bc432170-000000@ap-southeast-2.amazonses.com/raw";
        #       hash = "sha256-VnzxUqQZGyTrkLcGXCU7/6xPLz/U4Pf9svUu1upNcF8=";
        #     };
        #   }
        # ];

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

        # chainload the Windows bootloader on the separate Windows ESP
        loader.limine.extraEntries = ''
          /Windows
              protocol: efi
              path: guid(cf90b43d-bb12-4ef9-9fde-8e5c7c3adcff):/EFI/Microsoft/Boot/bootmgfw.efi
        '';

        # allow limine to take over the world
        loader.efi.canTouchEfiVariables = true;
      };

      # backup kernel
      specialisation.latest.configuration = {
        boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
      };

      hardware = {
        enableRedistributableFirmware = true;
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        cpu.intel.npu.enable = true;

        graphics = {
          enable = true;
          extraPackages = with pkgs; [
            intel-media-driver
            vpl-gpu-rt
          ];
        };

        opentabletdriver.enable = true;
        uinput.enable = true;
      };

      # crashes if service starts before DISPLAY/WAYLAND_DISPLAY are set
      systemd.user.services.opentabletdriver.after = [ "graphical-session.target" ];
    };
}
