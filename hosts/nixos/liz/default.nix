{
  config,
  inputs,
  microvmLib,
  ...
}:
let
  inherit (config.flake.modules) nixos;
  inherit (config.flake) keys;
in
{
  flake.modules.nixos."hosts/nixos/liz" =
    { config, lib, ... }:
    {
      imports = [
        ./_disko.nix
        ./_networking.nix
        ./_console.nix
        ./_vfio.nix
        ./_windows-vm.nix

        inputs.disko.nixosModules.default
        inputs.microvm.nixosModules.host
        (microvmLib.mkHostNetworking {
          n = 1;
          hostname = "vm-gallery";
        })
        (microvmLib.mkHostNetworking {
          n = 2;
          hostname = "vm-coder";
        })
        (microvmLib.mkHostNetworking {
          n = 3;
          hostname = "vm-gpu";
        })
      ]
      ++ (with nixos; [
        uefi
        zram
        sensors
        watchdog
        impermanence-zfs
        persistence
        sops

        callum
        colin

        ssh
        tailscale
        gateway
        cloudflared
        libvirt
        metrics
        monitoring
        logs
        samba
        syncthing-server
        qbittorrent

        radicale
        trilium
        memos
        quadlet-productivity
        quadlet-media
        quadlet-automation
        quadlet-development
        quadlet-immich
        quadlet-gotosocial

        attic
        buildbot
      ]);

      # https://microvm-nix.github.io/microvm.nix/declarative.html#fully-declarative

      microvm.vms = {
        vm-gallery = {
          config.imports = [
            nixos.base
            nixos.global
            nixos."hosts/nixos/vm-gallery"
          ];
          # nixos.base sets nixpkgs.config, which nixpkgs forbids once pkgs is
          # instantiated externally; force config-mode's eval-config to build
          # its own pkgs instead of reusing liz's already-built instance.
          pkgs = null;
          restartIfChanged = true;
        };

        vm-coder = {
          config.imports = [
            nixos.base
            nixos.global
            nixos."hosts/nixos/vm-coder"
          ];
          pkgs = null;
          nixpkgs = inputs.unstable;
          restartIfChanged = true;
        };

        vm-gpu = {
          config.imports = [
            nixos.base
            nixos.global
            nixos."hosts/nixos/vm-gpu"
          ];
          pkgs = null;
          nixpkgs = inputs.unstable;
          restartIfChanged = true;
          autostart = false;
        };
      };

      # The ordering dependency makes either guest stop completely before the
      # other starts when systemd resolves their mutual conflict.
      systemd.services = {
        windows-vm = {
          conflicts = [ "microvm@vm-gpu.service" ];
          after = [ "microvm@vm-gpu.service" ];
        };
        "microvm@vm-gpu".conflicts = [ "windows-vm.service" ];
      };

      _module.args.sshKeys = keys.callum;

      system.stateVersion = "25.11";
      networking.hostId = "19550836";

      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "ahci"
          "mpt3sas"
          "nvme"
          "usbhid"
          "usb_storage"
          "sd_mod"
        ];
        kernelModules = [ "kvm-amd" ];
        supportedFilesystems = [ "zfs" ];
        zfs.extraPools = [
          "tank"
          "scratch"
        ];
        zfs.forceImportRoot = false;

        # Demand misses barely improved between the previous 4.7 GiB ARC and 28 GiB;
        # 8 GiB leaves headroom while preserving RAM for page cache and the Windows VM.
        # ZFS first loads in the initrd, so the cap must be a modprobe option.
        extraModprobeConfig = "options zfs zfs_arc_max=8589934592";
      };

      nix = {
        settings = {
          max-jobs = 1;
          cores = 8;

          min-free = 21474836480; # 20 GiB
          max-free = 64424509440; # 60 GiB

          # shama's kernel and other chaotic packages; liz substitutes them
          # rather than compiling them when it builds shama's closure.
          extra-substituters = [ "https://nyx-cache.chaotic.cx/" ];
          extra-trusted-public-keys = [
            "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
          ];
        };

        gc.dates = lib.mkForce "daily";
      };

      services.zfs.autoScrub = {
        enable = true;
        interval = "monthly";
        pools = [
          "tank"
          "scratch"
        ];
      };

      hardware.enableRedistributableFirmware = true;
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      fileSystems."/mnt/media" = {
        device = "/dev/disk/by-uuid/0b878ab4-2310-4b8e-92e8-7ef5f47f75f8";
        fsType = "ext4";
      };

      modules = {
        sensors.chips = [ "nct6775" ];
        watchdog.driver = "sp5100_tco";

        buildbot = {
          domain = "buildbot.callumwong.com";
          repository = "wongcallum/nixos";
          admins = [ "wongcallum" ];
          githubAppId = 4715357;
          githubOauthId = "Iv23lipPVqv9ZuHat43o";
        };

        cloudflared = {
          tunnelId = "9b4ff5ef-f12d-4650-97e4-fad415bbcf71";
          credentialsSecret = "cloudflared/liz-credentials.json";
          ingress."buildbot.callumwong.com" = "http://127.0.0.1:8010";
        };

        samba.shares = {
          tank_colin = "/tank/colin";
          callum = "/tank/callum";
          photo = "/tank/photo";
          media = "/mnt/media";
          torrents = "/tank/torrents";

          games = "/scratch/games";
        };

        immich.externalLibraries = {
          photo = "/tank/photo";
          DCIM = "/tank/callum/syncthing/DCIM/Camera";
        };
      };
    };
}
