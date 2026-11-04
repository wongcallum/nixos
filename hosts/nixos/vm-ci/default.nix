{
  config,
  inputs,
  lib,
  vmLib,
  ...
}:
let
  inherit (config.flake.modules) nixos;
  inherit (config.flake) keys;

  hostname = "vm-ci";

  inherit (vmLib.vms.${hostname}) hostAddr guestAddr;

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
          (vmLib.mkGuestNetwork hostname)
        ]
        ++ (with nixos; [
          secrets

          callum

          ssh
          tailscale
          zram

          cloudflared
          nixbot

          logs
          metrics
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
          # It has its own disk, so it pushes its journal instead of liz reading it.
          logs.lokiAddr = hostAddr;

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
      { config, ... }:
      {
        imports = [ nixos.qemu-vms ];

        modules.qemuVms.${hostname} = {
          description = "CI virtual machine";
          user = hostname;

          smp = toString vcpu;
          memory = "${toString mem}M";

          disk = {
            zvol = vmLib.vmDisk "ci";
            sizeGiB = 128;
            compression = "zstd";
            serial = "ci";
          };
          boot = "uefi";

          extraArgs = [
            "-sandbox"
            "on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny"
            # Memory is a ceiling. Free page reporting returns what the guest frees.
            "-device"
            "virtio-balloon-pci,free-page-reporting=on,deflate-on-oom=on"
          ];

          hostPorts = [
            config.modules.attic.guestPort
            config.modules.monitoring.lokiPort
          ];
        };

        systemd.services.${hostname} = {
          # vm-ci deploys separately. Apply unit changes with `systemctl restart vm-ci`.
          restartIfChanged = false;
          serviceConfig = {
            TimeoutStopSec = "180s";
            Restart = "on-failure";
            RestartSec = "10s";
          };
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
