{
  config,
  inputs,
  lib,
  microvmLib,
  ...
}:
let
  inherit (config.flake.modules) nixos;
  inherit (config.flake) keys;

  hostname = "vm-ci";

  tap = hostname;
  hostAddr = "10.0.1.1";
  guestAddr = "10.0.1.4";
  guestMac = "02:00:00:00:01:04";

  vcpu = 6;
  mem = 16384; # MiB

  domain = "ci.callumwong.com";
  nixbotPort = 8010;
in
{
  flake.modules.nixos = {
    "hosts/nixos/${hostname}" =
      {
        config,
        modulesPath,
        pkgs,
        ...
      }:
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
          zram

          cloudflared
          nixbot
        ]);

        system.stateVersion = "26.05";

        warnings = lib.optional (keys.hermes == [ ]) ''
          flake.keys.hermes is empty, so hermes cannot reach the vm-ci nix daemon.
        '';

        # A trusted user could import arbitrary paths, which CI would push to attic.
        assertions = [
          {
            assertion = !(lib.elem "hermes" config.nix.settings.trusted-users);
            message = "hermes must stay an untrusted nix user on ${hostname}";
          }
        ];

        boot = {
          loader = {
            systemd-boot.enable = true;
            # Stops bootctl writing to liz's firmware during install. OVMF boots the removable path.
            efi.canTouchEfiVariables = false;
          };
          kernelParams = [
            "console=ttyS0"
            # Fragmentation leaves few free 2 MiB blocks, so the default order returned little memory.
            "page_reporting.page_reporting_order=5"
          ];
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
            networkConfig = microvmLib.guestDns;
          };
        };

        # pahole needs about 7 GiB for shama's kernel BTF. zram pages don't count
        # towards MemoryMax, so swap has its own cap.
        systemd.services.nix-daemon.serviceConfig = {
          MemoryMax = "10G";
          MemorySwapMax = "2G";
        };

        # Nix 2.34 wakes every waiting goal when a build finishes, and runs out of
        # memory on crane's many derivations.
        # workaround: vm-ci-nix-2-35
        nix.package = pkgs.nixVersions.nix_2_35;

        nix.settings = {
          max-jobs = 2;
          # Each build gets every vCPU because the kernel usually compiles alone.
          cores = vcpu;

          # base's 500 MB buffer per download ran the daemon out of memory on parallel fetches.
          download-buffer-size = lib.mkForce 67108864; # 64 MiB

          min-free = 21474836480; # 20 GiB
          max-free = 64424509440; # 60 GiB

          # Ask nyx after cache.nixos.org (40) instead of at its advertised 30, because nyx has few paths.
          extra-substituters = [
            "https://nyx-cache.chaotic.cx/?priority=45"
            "https://cache.nixos-cuda.org/"
            "https://cache.numtide.com"
          ];
          extra-trusted-public-keys = [
            "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
            "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
            "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
          ];
        };

        sops.defaultSopsFile = lib.mkForce "${inputs.secrets}/${hostname}.yaml";

        # This host builds untrusted PRs, so it has no password.
        modules.users.callum.lockPassword = true;

        users.users = {
          root.hashedPassword = "!";

          hermes = {
            isNormalUser = true;
            openssh.authorizedKeys.keys = map (
              key: ''restrict,command="${config.nix.package}/bin/nix-daemon --stdio" ${key}''
            ) keys.hermes;
          };
        };

        networking.firewall.allowedTCPPorts = [ nixbotPort ];
        services.nixbot.port = nixbotPort;

        modules = {
          attic = {
            endpoint = "http://${hostAddr}:${toString config.modules.attic.guestPort}/";
            priority = 10;
          };

          cloudflared = {
            tunnelId = "9b4ff5ef-f12d-4650-97e4-fad415bbcf71";
            credentialsSecret = "cloudflared/vm-ci-credentials.json";
            ingress.${domain} = "http://127.0.0.1:${toString nixbotPort}";
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

    "${hostname}-host" =
      { config, pkgs, ... }:
      let
        user = hostname;
        zvol = microvmLib.vmDisk "ci";
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
              zfs create -p -s -V 128G \
                -o volblocksize=16K \
                -o compression=zstd \
                "${zvol}"
            fi
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
              # Memory is a ceiling. Free page reporting returns what the guest frees.
              -device "virtio-balloon-pci,free-page-reporting=on,deflate-on-oom=on"
              -drive "file=${disk},if=none,id=disk,format=raw,cache=none,aio=native,discard=unmap,detect-zeroes=unmap"
              -device "virtio-blk-pci,drive=disk,serial=ci"
              -netdev "tap,id=net,ifname=${tap},script=no,downscript=no"
              -device "virtio-net-pci,netdev=net,mac=${guestMac}"
              -qmp "unix:${qmpSocket},server=on,wait=off"
            )
            exec qemu-system-x86_64 "''${args[@]}"
          '';
        };

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
              # vm-ci deploys separately. Apply unit changes with `systemctl restart vm-ci`.
              restartIfChanged = false;

              serviceConfig = {
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
              "100.64.0.0/10"
              "169.254.0.0/16"
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
