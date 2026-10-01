{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  # Plasma for the headless KWin session, matching liz's gpu-vm guest.
  flake.nixpkgs.salt = "unstable";

  flake.modules.nixos."hosts/nixos/salt" =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        ./_disko.nix

        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        uefi
        zram

        callum

        ssh
        tailscale
        sops
        remote-desktop

        metrics
        logs

        # cottage-witch
      ]);

      system.stateVersion = "25.11";

      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "ahci"
          "sd_mod"
        ];
        kernelModules = [ "kvm-intel" ];
        # Load HuC for the UHD 630's low-power (VDENC) encoder; Gen9 has no GuC submission.
        kernelParams = [ "i915.enable_guc=2" ];
      };

      hardware = {
        enableRedistributableFirmware = true;
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

        # punktfunk encodes through VAAPI on Intel.
        graphics.extraPackages = [ pkgs.intel-media-driver ];
      };

      environment = {
        sessionVariables.LIBVA_DRIVER_NAME = "iHD";
        systemPackages = [
          pkgs.libva-utils
          pkgs.intel-gpu-tools
        ];
      };

      # Stock Moonlight clients on the trusted LAN.
      services.punktfunk.host.gamestream = true;

      networking.useNetworkd = true;
      systemd = {
        network.enable = true;
        network.networks."10-eth" = {
          matchConfig.Name = "eno1";
          networkConfig = {
            DHCP = "ipv4";
            IPv6AcceptRA = true;
          };
          linkConfig.RequiredForOnline = "routable";
        };

        # An idle Plasma session must not suspend the box out from under clients.
        targets = lib.genAttrs [ "sleep" "suspend" "hibernate" "hybrid-sleep" ] (_: {
          enable = false;
        });
      };
    };
}
