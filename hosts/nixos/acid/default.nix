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
      ...
    }:
    {
      imports = [
        ./_disko.nix

        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        limine
        impermanence-btrfs
        callum
        ssh
        desktop
        t3code
        libvirt
      ]);

      system.stateVersion = "26.05";

      boot = {
        initrd.availableKernelModules = [
          "ahci"
          "xhci_pci"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];
        kernelModules = [ "kvm-intel" ];
      };

      hardware = {
        enableRedistributableFirmware = true;
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

        nvidia = {
          # 580 is the last branch to support Pascal, which the open modules never did.
          package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
          open = false;
          modesetting.enable = true;
        };
      };

      services.xserver.videoDrivers = [ "nvidia" ];

      # From niri's NVIDIA notes: without this, niri holds onto ~1 GiB of freed VRAM.
      environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
        builtins.toJSON {
          rules = [
            {
              pattern = {
                feature = "procname";
                matches = "niri";
              };
              profile = "Limit Free Buffer Pool On Wayland Compositors";
            }
          ];
          profiles = [
            {
              name = "Limit Free Buffer Pool On Wayland Compositors";
              settings = [
                {
                  key = "GLVidHeapReuseRatio";
                  value = 0;
                }
              ];
            }
          ];
        };

      systemd.targets = lib.genAttrs [ "sleep" "suspend" "hibernate" "hybrid-sleep" ] (_: {
        enable = false;
      });

      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
        settings.publish = {
          disable-publishing = false;
          publish-addresses = true;
        };
      };
    };
}
