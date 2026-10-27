{
  config,
  inputs,
  lib,
  ...
}:
{
  _module.args.microvmLib = rec {
    # liz's microVM guests; each index fixes the guest's MAC and 10.0.0.x address
    guests = {
      vm-gallery = 1;
      vm-thsconline = 3;
    };

    addressing =
      hostname:
      let
        n = guests.${hostname};
      in
      {
        hostAddr = "10.0.0.1";
        guestAddr = "10.0.0.${toString (n + 1)}";
        mac = "02:00:00:00:00:${lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString n))}";
      };

    # lockRoot: key-only root SSH instead of the default password login
    mkGuestModule =
      {
        hostname,
        lockRoot ? false,
      }:
      let
        addr = addressing hostname;
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

        users.users.root = lib.mkIf lockRoot {
          hashedPassword = "!";
          openssh.authorizedKeys.keys = config.flake.keys.callum;
        };

        services.openssh.settings = {
          PermitRootLogin = lib.mkForce (if lockRoot then "prohibit-password" else "yes");
          PasswordAuthentication = lib.mkForce (!lockRoot);
        };
      };

    mkHostNetworking =
      hostname:
      let
        addr = addressing hostname;
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
