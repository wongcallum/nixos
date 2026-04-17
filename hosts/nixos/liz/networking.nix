{
  flake.nixosModules.liz-networking =
    { pkgs, ... }:
    let
      netInterface = "eno1";
    in
    {
      networking.firewall = {
        enable = true;
        allowPing = true;
        allowedTCPPorts = [
          22
          53
          80
          443
          8123
          7070
          8887
        ];
      };

      systemd.network.wait-online.enable = false;
      boot.initrd.systemd.network.wait-online.enable = false;

      networking.useNetworkd = true;
      systemd.network.enable = true;
      systemd.network.networks."10-eth" = {
        matchConfig.Name = netInterface;
        address = [ "192.168.0.2/24" ];
        routes = [
          { Gateway = "192.168.0.1"; }
        ];
        linkConfig.RequiredForOnline = "routable";
      };

      services.resolved = {
        extraConfig = ''
          DNSStubListener = no
        '';
      };

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
    };
}
