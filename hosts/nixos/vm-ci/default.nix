{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (config.flake.modules) nixos;
  inherit (config.flake) keys;

  hostname = "vm-ci";

  # A point-to-point link on liz's 10.0.1.0/24 VM network. liz's address is a
  # /32 here, and the /32 route to the guest beats the GPU VM tap's /24.
  tap = hostname;
  hostAddr = "10.0.1.1";
  guestAddr = "10.0.1.4";
  guestMac = "02:00:00:00:01:04";

  vcpu = 6;
  mem = 12288; # MiB

  domain = "ci.callumwong.com";
  nixbotPort = 8010;
in
{
  flake.modules.nixos = {
    # A regular host with its own disk, bootloader and store, deployed on its
    # own with deploy-rs. liz only runs QEMU for it; see vm-ci-host.
    "hosts/nixos/${hostname}" =
      { config, modulesPath, ... }:
      {
        imports = [
          ./_disko.nix

          inputs.disko.nixosModules.default
          (modulesPath + "/profiles/qemu-guest.nix")
        ]
        ++ (with nixos; [
          sops

          callum

          ssh
          tailscale

          nixbot
        ]);

        system.stateVersion = "26.05";

        warnings = lib.optional (keys.hermes == [ ]) ''
          flake.keys.hermes is empty, so hermes cannot reach the vm-ci nix daemon.
        '';

        # A trusted user can register arbitrary store paths, which CI would
        # then treat as built and push to attic.
        assertions = [
          {
            assertion = !(lib.elem "hermes" config.nix.settings.trusted-users);
            message = "hermes must stay an untrusted nix user on ${hostname}";
          }
        ];

        boot = {
          loader = {
            systemd-boot.enable = true;
            # liz discards the firmware's settings on every start, and bootctl
            # must never write boot entries into liz's firmware during install.
            # It still installs the removable-media path, which OVMF boots.
            efi.canTouchEfiVariables = false;
          };
          # boot output lands in liz's journal for the vm-ci unit
          kernelParams = [ "console=ttyS0" ];
        };

        networking.useNetworkd = true;
        systemd.network = {
          enable = true;
          networks."10-eth" = {
            matchConfig.MACAddress = guestMac;
            address = [ "${guestAddr}/32" ];
            routes = [
              {
                Gateway = hostAddr;
                GatewayOnLink = true;
              }
            ];
            networkConfig.DNS = [ "1.1.1.1" ];
          };
        };

        # Builds run in the daemon's cgroup, so a runaway one is killed on
        # its own instead of the whole VM running out and taking nixbot with it.
        systemd.services.nix-daemon.serviceConfig.MemoryMax = "6G";

        nix.settings = {
          max-jobs = 2;
          cores = 3;

          min-free = 21474836480; # 20 GiB
          max-free = 64424509440; # 60 GiB

          # shama's kernel and other chaotic packages; substituted rather
          # than compiled when CI builds shama's closure
          extra-substituters = [
            "https://nyx-cache.chaotic.cx/"
            "https://cache.nixos-cuda.org/"
          ];
          extra-trusted-public-keys = [
            "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
            "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
          ];
        };

        # only the secrets this VM needs, not everything in secrets.yaml
        sops.defaultSopsFile = lib.mkForce "${inputs.secrets}/${hostname}.yaml";

        # SSH keys and passwordless sudo only: the password stays off a
        # machine that builds other people's pull requests
        modules.users.callum.lockPassword = true;

        users.users = {
          root.hashedPassword = "!";

          # hermes may only speak the nix daemon protocol (ssh-ng://), as an
          # untrusted user: it can build derivations, but not import paths.
          hermes = {
            isNormalUser = true;
            openssh.authorizedKeys.keys = map (
              key: ''restrict,command="${config.nix.package}/bin/nix-daemon --stdio" ${key}''
            ) keys.hermes;
          };
        };

        # liz proxies the web interface; the health check polls 127.0.0.1
        networking.firewall.allowedTCPPorts = [ nixbotPort ];
        services.nixbot.port = nixbotPort;

        modules = {
          attic = {
            endpoint = "http://${hostAddr}:${toString config.modules.attic.guestPort}/";
            # Ask attic before the public caches. Most of what CI looks up was
            # pushed there by an earlier run, and it answers in about a
            # millisecond, whereas a public cache costs a TLS handshake.
            priority = 10;
          };

          nixbot = {
            inherit domain;
            listenAddress = "0.0.0.0";
            repository = "wongcallum/nixos";
            admins = [ "wongcallum" ];
            githubAppId = 4715357;
            githubOauthId = "Iv23lipPVqv9ZuHat43o";
          };
        };
      };

    # imported by the host running the VM
    "${hostname}-host" =
      { config, pkgs, ... }:
      let
        user = hostname;
        zvol = "rpool/vm/ci";
        disk = "/dev/zvol/${zvol}";
        runDir = "/run/${hostname}";
        qmpSocket = "${runDir}/qmp.sock";
        firmware = "${pkgs.OVMF.fd}/FV";
        atticPort = config.modules.attic.guestPort;

        createVolume = pkgs.writeShellApplication {
          name = "${hostname}-volume";
          runtimeInputs = [ config.boot.zfs.package ];
          text = ''
            if ! zfs list -H -o name "${zvol}" >/dev/null 2>&1; then
              zfs create -s -V 256G \
                -o volblocksize=16K \
                -o compression=zstd \
                "${zvol}"
            fi
            # udev needs a moment to publish /dev/zvol after creation
            for _ in $(seq 1 50); do
              [ -b "${disk}" ] && exit 0
              sleep 0.1
            done
            echo "Missing ${hostname} block device: ${disk}" >&2
            exit 1
          '';
        };

        launch = pkgs.writeShellApplication {
          name = "${hostname}-launch";
          runtimeInputs = [
            pkgs.qemu_kvm
            pkgs.coreutils
          ];
          text = ''
            # Fresh firmware settings every start. Nothing needs to persist in
            # them: the guest boots the removable-media path.
            install -m 600 ${firmware}/OVMF_VARS.fd ${runDir}/OVMF_VARS.fd

            args=(
              -name "${hostname}"
              -machine "q35,accel=kvm"
              -cpu host
              -smp ${toString vcpu}
              -m ${toString mem}M
              -nodefaults
              -no-user-config
              -display none
              -sandbox "on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny"
              -drive "if=pflash,format=raw,readonly=on,file=${firmware}/OVMF_CODE.fd"
              -drive "if=pflash,format=raw,file=${runDir}/OVMF_VARS.fd"
              -chardev "stdio,id=stdio,signal=off"
              -serial "chardev:stdio"
              -device virtio-rng-pci
              # a ceiling rather than a reservation: free page reporting hands
              # memory the guest frees back to the host
              -device "virtio-balloon-pci,free-page-reporting=on,deflate-on-oom=on"
              # discard=unmap lets the guest's TRIM reclaim sparse zvol space
              -drive "file=${disk},if=none,id=disk,format=raw,cache=none,aio=native,discard=unmap,detect-zeroes=unmap"
              -device "virtio-blk-pci,drive=disk,serial=ci"
              -netdev "tap,id=net,ifname=${tap},script=no,downscript=no"
              -device "virtio-net-pci,netdev=net,mac=${guestMac}"
              -qmp "unix:${qmpSocket},server=on,wait=off"
            )
            exec qemu-system-x86_64 "''${args[@]}"
          '';
        };

        # Ask the guest to power down cleanly, then keep ExecStop alive until QEMU exits.
        shutdown = pkgs.writeShellApplication {
          name = "${hostname}-shutdown";
          runtimeInputs = [ pkgs.socat ];
          text = ''
            [ -S "${qmpSocket}" ] || exit 0
            printf '%s\n%s\n' \
              '{"execute":"qmp_capabilities"}' \
              '{"execute":"system_powerdown"}' \
              | socat - "UNIX-CONNECT:${qmpSocket}" >/dev/null || true
            mainPid="''${MAINPID:-}"
            [ -n "$mainPid" ] || exit 0
            while kill -0 "$mainPid" 2>/dev/null; do
              sleep 1
            done
          '';
        };
      in
      {
        users = {
          users.${user} = {
            isSystemUser = true;
            group = user;
          };
          groups.${user} = { };
        };

        systemd = {
          network = {
            netdevs."25-${tap}" = {
              netdevConfig = {
                Name = tap;
                Kind = "tap";
              };
              tapConfig = {
                User = user;
                Group = user;
              };
            };

            networks."25-${tap}" = {
              matchConfig.Name = tap;
              address = [ "${hostAddr}/32" ];
              routes = [
                {
                  Destination = "${guestAddr}/32";
                  Scope = "link";
                }
              ];
              networkConfig.ConfigureWithoutCarrier = true;
              linkConfig.RequiredForOnline = false;
            };
          };

          services = {
            "${hostname}-volume" = {
              description = "Provision the ${hostname} zvol";
              after = [ "zfs.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = lib.getExe createVolume;
              };
            };

            ${hostname} = {
              description = "CI virtual machine";
              wantedBy = [ "multi-user.target" ];
              requires = [ "${hostname}-volume.service" ];
              after = [
                "${hostname}-volume.service"
                "systemd-networkd.service"
              ];
              # vm-ci is deployed on its own; changes to this unit apply on
              # `systemctl restart vm-ci`, never by surprise during a liz deploy
              restartIfChanged = false;

              serviceConfig = {
                # follows the /dev/zvol symlink to the device node
                ExecStartPre = "+${lib.getExe' pkgs.coreutils "chown"} ${user} ${disk}";
                ExecStart = lib.getExe launch;
                ExecStop = lib.getExe shutdown;
                TimeoutStopSec = "180s";
                Restart = "on-failure";
                RestartSec = "10s";

                User = user;
                Group = user;
                SupplementaryGroups = [ "kvm" ];
                RuntimeDirectory = hostname;
                RuntimeDirectoryMode = "0700";

                DevicePolicy = "closed";
                DeviceAllow = [
                  "/dev/kvm rw"
                  "/dev/net/tun rw"
                  "block-zvol rw"
                ];
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectControlGroups = true;
              };
            };
          };
        };

        networking = {
          nat = {
            enable = true;
            internalInterfaces = [ tap ];
          };

          #
          #   guest 10.0.1.4 (on the vm-ci tap)
          #     |
          #     +- to host -> nixos-fw -> vm-ci-in -+- tcp/8081 (attic) -> ACCEPT
          #     |                                   +- any other NEW ---> DROP
          #     |
          #     +- routed --> FORWARD --> vm-ci-fwd +- ESTABLISHED,RELATED -> ACCEPT
          #                                         |  (replies to liz and tailnet clients)
          #                                         +- 10/8, 172.16/12, -> DROP
          #                                         |  192.168/16,
          #                                         |  100.64/10, 169.254/16
          #                                         +- anything else ---> NAT -> internet
          #
          firewall.extraCommands = ''
            iptables -N vm-ci-in 2>/dev/null || iptables -F vm-ci-in
            iptables -A vm-ci-in -p tcp --dport ${toString atticPort} -j nixos-fw-accept
            iptables -A vm-ci-in -m conntrack --ctstate NEW -j DROP
            iptables -D nixos-fw -i ${tap} -j vm-ci-in 2>/dev/null || true
            iptables -I nixos-fw -i ${tap} -j vm-ci-in

            iptables -N vm-ci-fwd 2>/dev/null || iptables -F vm-ci-fwd
            iptables -A vm-ci-fwd -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
            ${lib.concatMapStringsSep "\n" (dest: "iptables -A vm-ci-fwd -d ${dest} -j DROP") [
              "10.0.0.0/8"
              "172.16.0.0/12"
              "192.168.0.0/16"
              "100.64.0.0/10" # tailnet (CGNAT)
              "169.254.0.0/16" # link-local, incl. cloud metadata
            ]}
            iptables -D FORWARD -i ${tap} -j vm-ci-fwd 2>/dev/null || true
            iptables -I FORWARD -i ${tap} -j vm-ci-fwd
          '';

          firewall.extraStopCommands = ''
            iptables -D nixos-fw -i ${tap} -j vm-ci-in 2>/dev/null || true
            iptables -D FORWARD -i ${tap} -j vm-ci-fwd 2>/dev/null || true
            iptables -F vm-ci-in 2>/dev/null || true
            iptables -X vm-ci-in 2>/dev/null || true
            iptables -F vm-ci-fwd 2>/dev/null || true
            iptables -X vm-ci-fwd 2>/dev/null || true
          '';
        };

        modules = {
          attic.guestAddress = hostAddr;

          cloudflared.ingress.${domain} = "http://${guestAddr}:${toString nixbotPort}";

          gateway.services.nixbot = {
            name = "nixbot";
            domainName = "nixbot";
            iconUrl = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/nixos.svg";
            addr = "${guestAddr}:${toString nixbotPort}";
            category = "Development";
          };
        };
      };
  };
}
