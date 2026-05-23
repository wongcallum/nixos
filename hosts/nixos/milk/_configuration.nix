{
  config,
  lib,
  ...
}:
{
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
      reverse_proxy 100.93.214.80:3000
    '';
  };
}
