{ lib, pkgs, ... }:
let
  # The B550-PLUS's onboard Realtek RTL8125 2.5GbE, driven by r8169 — not the
  # `eno1` the Z370's onboard Intel I219-V used to get.
  #
  # The name is pinned to the MAC rather than inherited from PCI topology. During
  # the board swap this interface was `enp6s0`; fitting the Patriot in M.2_2
  # inserted a device ahead of it on the bus and it became `enp7s0` — a storage
  # change renaming the NIC. liz has no display, so a rename it isn't expecting is
  # a total loss of network, recoverable only over the serial console. Pinning to
  # the MAC makes any future PCIe topology change a non-event.
  netInterface = "lan0";
  netMac = "50:eb:f6:97:a1:6a";

  # Shared by the initrd and the booted system so the two cannot drift. They are
  # never up at the same time — initrd sshd is torn down at switch-root — so
  # reusing the address is safe, and _console.nix already puts initrd sshd on 2222
  # to keep the two host keys out of each other's known_hosts.
  netAddress = "192.168.0.2/24";
  netGateway = "192.168.0.1";

  # Applied to the initrd as well as the booted system. initrd networkd brings
  # this NIC up for the emergency sshd in _console.nix, and an interface cannot be
  # renamed once it is up — so it has to carry the right name from the start,
  # not acquire it in stage 2.
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

  # A static address in the initrd, rather than the DHCP the stock
  # 99-ethernet-default-dhcp.network would give it.
  #
  # Measured on the first boot: initrd sshd bound 2222 at T+0s, carrier arrived at
  # T+2s and switch-root killed it at T+3s — DHCP never completed, so the rescue
  # net had no IPv4 address at all. On a healthy boot that does not matter (there
  # is nothing to rescue), but it also meant the net could not be *proven* to work.
  # A static address is up the instant carrier appears, is at a known address
  # rather than whatever the router hands out, and still works when the router
  # itself is the problem. `10-` sorts ahead of the `99-` DHCP default, so this
  # wins the match.
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
