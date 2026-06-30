{ pkgs, ... }:
let
  netInterface = "eno1";
in
{
  networking = {
    firewall = {
      enable = true;
      allowPing = true;
    };
    nat.externalInterface = netInterface;
    useNetworkd = true;
  };

  boot.initrd.systemd.network.wait-online.enable = false;

  systemd.network = {
    wait-online.enable = false;
    enable = true;
    networks."10-eth" = {
      matchConfig.Name = netInterface;
      address = [ "192.168.0.2/24" ];
      routes = [
        { Gateway = "192.168.0.1"; }
      ];
      linkConfig.RequiredForOnline = "routable";
    };
  };

  services.resolved.settings.Resolve.DNSStubListener = "no";

  environment.systemPackages = [ pkgs.ethtool ];
  services.networkd-dispatcher = {
    enable = true;
    rules."50-tailscale-optimizations" = {
      onState = [ "routable" ];
      script = ''
        ${pkgs.ethtool}/bin/ethtool -K ${netInterface} rx-udp-gro-forwarding on rx-gro-list off
      '';
    };
  };
}
