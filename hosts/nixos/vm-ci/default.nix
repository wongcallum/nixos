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

  n = 5;
  hostname = "vm-ci";
  addr = microvmLib.addressing n;

  domain = "ci.callumwong.com";
  nixbotPort = 8010;

  # relative to the VM's directory under the host's microvm.stateDir
  storeImage = "nix-store.img";
  storeOverlay = "/nix/.rw-store";
in
{
  flake.modules.nixos = {
    "hosts/nixos/${hostname}" =
      { config, ... }:
      {
        imports = [
          (microvmLib.mkGuestModule {
            inherit n hostname;
            shareHostStore = false;
          })
        ]
        ++ (with nixos; [
          persistence
          sops

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

        microvm = {
          vcpu = 6;
          # a ceiling rather than a reservation: free page reporting hands
          # memory the guest frees back to liz
          mem = 12288;
          balloon = true;

          # CI builds in a store of its own instead of a view of liz's. The
          # overlay is recreated empty on every VM start (see the host module
          # below), so nothing outlives a restart and the database registered
          # at boot always matches what is on disk. attic keeps the outputs.
          writableStoreOverlay = storeOverlay;
          volumes = [
            {
              image = storeImage;
              mountPoint = storeOverlay;
              size = 262144; # 256 GiB, sparse
            }
          ];
        };

        systemd.tmpfiles.rules = [ "d ${storeOverlay}/build 0755 root root -" ];

        nix.settings = {
          # the default under /nix/var sits on the tmpfs root
          build-dir = "${storeOverlay}/build";

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

        users.users = {
          root = {
            hashedPassword = "!";
            openssh.authorizedKeys.keys = keys.callum;
          };

          # hermes may only speak the nix daemon protocol (ssh-ng://), as an
          # untrusted user: it can build derivations, but not import paths.
          hermes = {
            isNormalUser = true;
            openssh.authorizedKeys.keys = map (
              key: ''restrict,command="${config.nix.package}/bin/nix-daemon --stdio" ${key}''
            ) keys.hermes;
          };
        };

        services.openssh.settings = {
          PermitRootLogin = lib.mkOverride 40 "prohibit-password";
          PasswordAuthentication = lib.mkOverride 40 false;
        };

        # liz proxies the web interface; the health check polls 127.0.0.1
        networking.firewall.allowedTCPPorts = [ nixbotPort ];
        services.nixbot.port = nixbotPort;

        modules = {
          attic.endpoint = "http://${addr.hostAddr}:${toString config.modules.attic.guestPort}/";

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
      {
        imports = [
          (microvmLib.mkHostNetworking {
            inherit n hostname;
            # attic, to substitute from and push to
            allowedHostTCPPorts = [ config.modules.attic.guestPort ];
          })
        ];

        microvm.vms.${hostname} = {
          config.imports = [
            nixos.base
            nixos.global
            nixos."hosts/nixos/${hostname}"
          ];
          pkgs = null;
          restartIfChanged = true;
        };

        # start every boot from an empty store
        systemd.services."microvm@${hostname}".serviceConfig.ExecStartPre =
          "${lib.getExe' pkgs.coreutils "rm"} -f ${config.microvm.stateDir}/${hostname}/${storeImage}";

        modules = {
          cloudflared.ingress.${domain} = "http://${addr.guestAddr}:${toString nixbotPort}";

          gateway.services.nixbot = {
            name = "nixbot";
            domainName = "nixbot";
            iconUrl = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/nixos.svg";
            addr = "${addr.guestAddr}:${toString nixbotPort}";
            category = "Development";
          };
        };
      };
  };
}
