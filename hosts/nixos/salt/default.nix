{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  # Matches liz's gpu-vm guest, which runs the same headless sway session.
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

      services.punktfunk.host = {
        # workaround: https://github.com/wongcallum/nixos/issues/83
        # Gen9's HEVC encoder advertises no block sizes, and punktfunk's fallback
        # headers disagree with what it codes, so the stream is undecodable.
        package =
          inputs.punktfunk.packages.${pkgs.stdenv.hostPlatform.system}.punktfunk-host.overrideAttrs
            (old: {
              patches = (old.patches or [ ]) ++ [ ../../../patches/punktfunk-hevc-guessed-features.patch ];
            });
        # Stock Moonlight clients on the trusted LAN.
        gamestream = true;
      };

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

        # An idle sway session must not suspend the box out from under clients.
        targets = lib.genAttrs [ "sleep" "suspend" "hibernate" "hybrid-sleep" ] (_: {
          enable = false;
        });
      };
    };
}
