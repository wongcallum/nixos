{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixpkgs.acid = "unstable";

  flake.modules.nixos."hosts/nixos/acid" =
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

        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        limine
        console-font
        zram

        callum
        ssh
        tailscale
        autofs
        cryptomatord
        zed
        freesmlauncher
        disk-utils
        nix-monitored
        nix-discord-rpc

        impermanence-btrfs

        audio
        desktop
        niri
        keyd
        libvirt
        docker
        fonts
        bluetooth
        firefox
        ghostty
        thunderbird
        nix-ld
        syncthing-desktop
        direnv
        zoxide
        helium
        trilium-desktop
      ]);

      system.stateVersion = "26.05";

      services = {
        llama-cpp = {
          enable = true;
          package = pkgs.llama-cpp.override { cudaSupport = true; };
          settings = {
            host = "127.0.0.1";
            port = 8080;

            hf-repo = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q6_K_XL";
            alias = "qwen3.6-35b-a3b";

            n-cpu-moe = 64;
            n-gpu-layers = 99;
            kv-offload = true;
            threads = 12;
            threads-batch = 12;
            ctx-size = 262144;
            flash-attn = "on";
            cache-type-k = "q8_0";
            cache-type-v = "q8_0";
            spec-draft-type-k = "q8_0";
            spec-draft-type-v = "q8_0";
            parallel = 1;

            # https://unsloth.ai/docs/models/qwen3.6#llama.cpp-mtp-guide
            temp = 0.6;
            top-p = 0.95;
            top-k = 20;
            min-p = 0.00;
            spec-type = "draft-mtp";
            spec-draft-n-max = 2;
          };
        };

        resolved.enable = true;
        xserver.videoDrivers = [ "nvidia" ];
      };
      systemd = {
        services.llama-cpp.serviceConfig = {
          Environment = lib.mkForce [
            "CUDA_VISIBLE_DEVICES=GPU-41a667ec-3e58-e64c-1eeb-fb916f0b286f"
            "LLAMA_CACHE=/var/lib/llama-cpp/cache"
          ];
          TimeoutStartSec = "infinity";
        };

        user.services.niri.environment.NIRI_CONFIG = "/etc/niri/acid.kdl";
        user.services.opentabletdriver.after = [ "graphical-session.target" ];
      };

      environment.etc."niri/acid.kdl".text = ''
        include optional=true "/home/callum/.config/niri/config.kdl";

        debug {
          render-drm-device "/dev/dri/by-path/pci-0000:04:00.0-render"
          ignore-drm-device "/dev/dri/by-path/pci-0000:07:00.0-render"
        }
      '';

      environment.variables = {
        EDITOR = "nvim";
        GOPATH = "/home/callum/.local/share/go";
        GOBIN = "/home/callum/.local/bin";
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
      documentation.man.cache.enable = false;

      modules = {
        syncthing-desktop.user = "callum";
        firefox.transparency = {
          enableToolbox = true;
          enablePage = true;
        };
      };

      users.users.callum.extraGroups = [
        "networkmanager"
        "adbusers"
      ];
      users.users.callum.initialPassword = lib.mkForce null;

      fileSystems."/games" = {
        device = "/dev/disk/by-uuid/6d374cf5-77a0-4d97-8f25-86622c9e74f0";
        fsType = "ext4";
      };

      boot = {
        # Keep the text console (and tuigreet) on the 1060's framebuffer.
        # fb0 is the CUDA-only 3060; fb1 is the display 1060.
        kernelParams = [ "fbcon=map:1" ];

        loader.efi.canTouchEfiVariables = true;

        initrd.availableKernelModules = [
          "nvme"
          "xhci_pci"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];
      };

      specialisation.LinuxLatest.configuration = {
        boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
      };

      hardware = {
        enableRedistributableFirmware = true;
        cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

        graphics.enable = true;

        opentabletdriver.enable = true;
        uinput.enable = true;

        nvidia = {
          package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
          modesetting.enable = true;
          open = false;
        };
      };

    };
}
