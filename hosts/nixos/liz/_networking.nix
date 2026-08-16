{ lib, pkgs, ... }:
let
  # Stable across PCI topology changes that rename predictable interfaces.
  netInterface = "lan0";
  netMac = "50:eb:f6:97:a1:6a";

  netAddress = "192.168.0.2/24";
  netGateway = "192.168.0.1";

  linkUnit = {
    matchConfig.MACAddress = netMac;
    linkConfig.Name = netInterface;
  };

  networkUnit = {
    matchConfig.Name = netInterface;
    address = [ netAddress ];
    routes = [ { Gateway = netGateway; } ];
  };
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

  boot.initrd.systemd.network = {
    wait-online.enable = false;
    links."10-lan" = linkUnit;
    networks."10-lan" = networkUnit;
  };

  systemd.network = {
    wait-online.enable = false;
    enable = true;
    links."10-lan" = linkUnit;
    networks."10-eth" = lib.mkMerge [
      networkUnit
      { linkConfig.RequiredForOnline = "routable"; }
    ];
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
