{
  config,
  inputs,
  lib,
  ...
}:
{
  _module.args.vmLib = rec {
    # Every VM liz runs. Each gets a point-to-point tap named after it.
    vms = {
      vm-gallery = {
        runner = "microvm";
        hostAddr = "10.0.0.1";
        guestAddr = "10.0.0.2";
        mac = "02:00:00:00:00:01";
      };
      vm-thsconline = {
        runner = "microvm";
        hostAddr = "10.0.0.1";
        guestAddr = "10.0.0.4";
        mac = "02:00:00:00:00:03";
      };
      vm-gpu = {
        runner = "qemu";
        hostAddr = "10.0.1.1";
        guestAddr = "10.0.1.3";
        mac = "02:00:00:00:01:03";
      };
      vm-ci = {
        runner = "qemu";
        hostAddr = "10.0.1.1";
        guestAddr = "10.0.1.4";
        mac = "02:00:00:00:01:04";
      };
    };
    microvmGuests = lib.filterAttrs (_: vm: vm.runner == "microvm") vms;

    privateRanges = [
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
      "100.64.0.0/10"
      "169.254.0.0/16"
    ];

    # All of a VM's data, disks included, lives under rpool/vm/<name>.
    vmName = hostname: lib.removePrefix "vm-" hostname;
    vmParent = "rpool/vm";
    vmDataset = name: "${vmParent}/${name}";
    vmDir = name: "/vm/${name}";
    vmDisk = name: "${vmDataset name}/disk";

    guestDns = {
      DNS = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
      ];
      DNSOverTLS = true;
    };

    mkVmStorage =
      { name, requiredBy }:
      { config, ... }:
      let
        dataset = vmDataset name;
      in
      {
        # The guest persists its journal here, so the host's Alloy ships it.
        modules.logs.journalDirs = [ "${vmDir name}/var/log/journal" ];

        systemd.services."vm-storage-${name}" = {
          description = "Provision the ${dataset} dataset";
          after = [ "zfs-mount.service" ];
          before = requiredBy;
          inherit requiredBy;
          path = [ config.boot.zfs.package ];
          script = ''
            zfs list -H -o name ${dataset} >/dev/null 2>&1 || zfs create -p ${dataset}
            [ "$(zfs get -H -o value mounted ${dataset})" = yes ] || zfs mount ${dataset}
            # sshd reads authorized_keys.d as the user, so /etc/ssh must stay traversable.
            install -d -m 0755 ${vmDir name}/etc/ssh
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };
      };

    mkGuestStorage =
      hostname:
      mkVmStorage {
        name = vmName hostname;
        requiredBy = [
          "microvm-virtiofsd@${hostname}.service"
          "microvm@${hostname}.service"
        ];
      };

    # lockRoot makes root SSH key-only instead of the default password login.
    mkGuestModule =
      {
        hostname,
        lockRoot ? false,
      }:
      let
        addr = vms.${hostname};
      in
      {
        imports = [
          inputs.microvm.nixosModules.microvm
          (mkGuestNetwork hostname)
          config.flake.modules.nixos.metrics
        ];

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
              source = vmDir (vmName hostname);
              mountPoint = "/persist";
              proto = "virtiofs";
            }
          ];
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

    mkGuestNetwork =
      hostname:
      let
        vm = vms.${hostname};
      in
      {
        networking.useNetworkd = true;
        systemd.network.networks."10-eth" = {
          matchConfig.MACAddress = vm.mac;
          address = [ "${vm.guestAddr}/32" ];
          routes = [
            {
              Gateway = vm.hostAddr;
              GatewayOnLink = true;
            }
          ];
          networkConfig = guestDns;
        };
      };

    # liz's end of a VM's tap: address, NAT, and a firewall that only lets the guest
    # reach hostPorts on liz and nothing private beyond it.
    mkHostLink =
      hostname:
      {
        hostPorts ? [ ],
      }:
      let
        vm = vms.${hostname};
        tap = hostname;
      in
      {
        systemd.network.networks."25-${tap}" = {
          matchConfig.Name = tap;
          address = [ "${vm.hostAddr}/32" ];
          routes = [
            {
              Destination = "${vm.guestAddr}/32";
              Scope = "link";
            }
          ];
          networkConfig.ConfigureWithoutCarrier = true;
          linkConfig.RequiredForOnline = false;
        };

        networking = {
          nat = {
            enable = true;
            internalInterfaces = [ tap ];
          };

          firewall.extraCommands = ''
            iptables -N ${tap}-in 2>/dev/null || iptables -F ${tap}-in
            ${lib.concatMapStrings (port: ''
              iptables -A ${tap}-in -p tcp --dport ${toString port} -j nixos-fw-accept
            '') hostPorts}
            iptables -A ${tap}-in -m conntrack --ctstate NEW -j DROP
            iptables -D nixos-fw -i ${tap} -j ${tap}-in 2>/dev/null || true
            iptables -I nixos-fw -i ${tap} -j ${tap}-in

            iptables -N ${tap}-fwd 2>/dev/null || iptables -F ${tap}-fwd
            iptables -A ${tap}-fwd -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
            ${lib.concatMapStrings (dest: ''
              iptables -A ${tap}-fwd -d ${dest} -j DROP
            '') privateRanges}
            iptables -D FORWARD -i ${tap} -j ${tap}-fwd 2>/dev/null || true
            iptables -I FORWARD -i ${tap} -j ${tap}-fwd
          '';

          firewall.extraStopCommands = ''
            iptables -D nixos-fw -i ${tap} -j ${tap}-in 2>/dev/null || true
            iptables -D FORWARD -i ${tap} -j ${tap}-fwd 2>/dev/null || true
            iptables -F ${tap}-in 2>/dev/null || true
            iptables -X ${tap}-in 2>/dev/null || true
            iptables -F ${tap}-fwd 2>/dev/null || true
            iptables -X ${tap}-fwd 2>/dev/null || true
          '';
        };
      };
  };
}
