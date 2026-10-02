{ inputs, lib, ... }:
{
  _module.args.microvmLib = rec {
    addressing = n: {
      hostAddr = "10.0.0.1";
      guestAddr = "10.0.0.${toString (n + 1)}";
      mac = "02:00:00:00:00:${lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString n))}";
    };

    mkGuestModule =
      { n, hostname }:
      let
        addr = addressing n;
      in
      {
        imports = [ inputs.microvm.nixosModules.microvm ];

        networking.useNetworkd = true;

        nix.optimise.automatic = lib.mkForce false;

        microvm = {
          hypervisor = lib.mkDefault "qemu";
          vcpu = lib.mkDefault 4;
          mem = lib.mkDefault 4096;
          interfaces = [
            {
              type = "tap";
              id = hostname;
              inherit (addr) mac;
            }
          ];
          shares = [
            {
              tag = "store";
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
              proto = "virtiofs";
            }
            {
              tag = "persist";
              source = "/persist/microvms/${hostname}";
              mountPoint = "/persist";
              proto = "virtiofs";
            }
          ];
        };

        systemd.network = {
          enable = true;
          networks."10-eth" = {
            matchConfig.MACAddress = addr.mac;
            address = [ "${addr.guestAddr}/32" ];
            routes = [
              {
                Gateway = addr.hostAddr;
                GatewayOnLink = true;
              }
            ];
            networkConfig.DNS = [ "1.1.1.1" ];
          };
        };

        services.openssh.settings = {
          PermitRootLogin = lib.mkForce "yes";
          PasswordAuthentication = lib.mkForce true;
        };
      };

    mkHostNetworking =
      { n, hostname }:
      let
        addr = addressing n;
        vmDir = "/persist/microvms/${hostname}";

        blockedDestinations = [
          "10.0.0.0/8"
          "172.16.0.0/12"
          "192.168.0.0/16"
          "100.64.0.0/10" # tailnet (CGNAT)
          "169.254.0.0/16" # link-local, incl. cloud metadata
        ];

        forwardDrop = op: dest: "iptables -${op} FORWARD -i ${hostname} -d ${dest} -j DROP";

        addForwardDrops = lib.concatMapStringsSep "\n" (dest: ''
          ${forwardDrop "D" dest} 2>/dev/null || true
          ${forwardDrop "I" dest}
        '') blockedDestinations;

        delForwardDrops = lib.concatMapStringsSep "\n" (
          dest: "${forwardDrop "D" dest} 2>/dev/null || true"
        ) blockedDestinations;
      in
      {
        systemd.network.networks."10-${hostname}" = {
          matchConfig.Name = hostname;
          address = [ "${addr.hostAddr}/32" ];
          networkConfig.ConfigureWithoutCarrier = true;
          routes = [
            {
              Destination = "${addr.guestAddr}/32";
              Scope = "link";
            }
          ];
        };

        networking = {
          nat = {
            enable = true;
            internalInterfaces = [ hostname ];
          };

          # Block guest-initiated connections to the host, and forwarded
          # guest traffic to anything on the LAN or the tailnet.
          firewall.extraCommands = ''
            iptables -I nixos-fw -i ${hostname} -m conntrack --ctstate NEW -j DROP
            ${addForwardDrops}
          '';
          firewall.extraStopCommands = ''
            iptables -D nixos-fw -i ${hostname} -m conntrack --ctstate NEW -j DROP 2>/dev/null || true
            ${delForwardDrops}
          '';
        };

        systemd.tmpfiles.rules = [
          "d ${vmDir} 0755 root root -"
          "d ${vmDir}/etc/ssh 0700 root root -"
        ];
      };
  };
}
