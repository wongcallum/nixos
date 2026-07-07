{ inputs, config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.modules.nixos."hosts/nixos/milk" =
    { config, lib, ... }:
    {
      imports = with nixos; [
        "${inputs.nixpkgs}/nixos/modules/virtualisation/digital-ocean-image.nix"

        callum

        ssh
        tailscale
        metrics
        logs
      ];

      system.stateVersion = "25.11";

      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      services.caddy = {
        enable = true;
        email = "mail@callumwong.com";
        virtualHosts."gallery.callumwong.com".extraConfig = ''
          reverse_proxy ${config.modules.hostAddrs.vm-gallery}:3000
        '';
      };
    };
}
