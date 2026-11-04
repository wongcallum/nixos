{ inputs, lib, ... }:
let
  # Hardcoded upstream.
  stateDir = "/var/lib/nixbot";
  postgresDir = "/var/lib/postgresql";

  # The patch changes the module too, so import it from the patched source.
  # workaround: nixbot-eval-options
  nixbotSrc = inputs.nixpkgs.legacyPackages.x86_64-linux.applyPatches {
    name = "nixbot-source";
    src = inputs.nixbot;
    patches = [ ../../patches/nixbot-eval-nix-options.patch ];
  };
in
{
  flake.modules.nixos = {
    nixbot =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.modules.nixbot;

        inherit (config.modules.attic) cacheName;
        cacheUrl = config.modules.attic.endpoint;

        atticClientConfig = (pkgs.formats.toml { }).generate "attic-client-config.toml" {
          default-server = cacheName;
          servers.${cacheName} = {
            endpoint = cacheUrl;
            token-file = config.security.nix-secrets.secrets."attic/push-token".path;
          };
        };

        pushToCache = pkgs.writeShellApplication {
          name = "nixbot-attic-push";
          runtimeInputs = [
            pkgs.attic-client
            pkgs.coreutils
          ];
          text = ''
            config_home="$(mktemp -d)"
            trap 'rm -rf "$config_home"' EXIT
            install -Dm600 ${atticClientConfig} "$config_home/attic/config.toml"

            XDG_CONFIG_HOME="$config_home" attic push --stdin --jobs 1 ${cacheName}
          '';
        };

        # Deploy key for the private secrets input. The prefetch runs with a throwaway
        # $HOME, but OpenSSH reads ~/.ssh from the passwd home.
        fetchSshConfig = pkgs.writeText "nixbot-fetch-ssh-config" ''
          Host github.com
            IdentityFile ${config.security.nix-secrets.secrets."nixbot/github-deploy-key".path}
            IdentitiesOnly yes
        '';
      in
      {
        imports = [ "${nixbotSrc}/nixosModules/nixbot.nix" ];

        options.modules.nixbot = {
          domain = lib.mkOption {
            type = lib.types.str;
            example = "ci.example.com";
            description = "Public hostname the web interface is reached at";
          };

          repository = lib.mkOption {
            type = lib.types.str;
            example = "owner/repo";
            description = "The only repository CI is allowed to build";
          };

          admins = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "GitHub usernames allowed to log in, trigger builds and change settings";
          };

          listenAddress = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "Address the web interface and webhook receiver listen on";
          };

          githubAppId = lib.mkOption {
            type = lib.types.int;
            default = 0;
          };

          githubOauthId = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "Iv23liAbCdEfGhIjKlMn";
          };
        };

        config = {
          warnings = lib.optional (cfg.githubAppId == 0 || cfg.githubOauthId == "") ''
            modules.nixbot.githubAppId or githubOauthId is unset, so nixbot
            cannot authenticate against GitHub. Create the app, then fill both values
            from its settings page.
          '';

          security.nix-secrets.secrets = {
            "nixbot/github-app-key".restartUnits = [ "nixbot.service" ];
            "nixbot/github-webhook-secret".restartUnits = [ "nixbot.service" ];
            "nixbot/github-oauth-secret".restartUnits = [ "nixbot.service" ];

            "attic/push-token".owner = "nixbot";

            "nixbot/github-deploy-key" = {
              owner = "nixbot";
              restartUnits = [ "nixbot.service" ];
            };
          };

          programs.ssh.knownHosts."github.com".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

          services.nixbot = {
            enable = true;
            inherit (cfg) domain;
            admins = map (admin: "github:${admin}") cfg.admins;

            nginx.enable = false;
            useHTTPS = true;
            buildSystems = [ "x86_64-linux" ];

            buildConcurrency = 1;
            # A hard cap. liz's eval peaks around 5.3 GiB.
            evalWorkerCount = 1;
            evalMaxMemorySize = 6144;

            # Cache status checks ask every substituter about each uncached path, so eval
            # skips the extra ones. The daemon rejects substituters missing from nix.conf.
            evalNixOptions.substituters = lib.concatStringsSep " " (
              [ config.modules.attic.substituter ] ++ config.nix.settings.substituters
            );

            github = {
              enable = true;
              appId = cfg.githubAppId;
              appSecretKeyFile = config.security.nix-secrets.secrets."nixbot/github-app-key".path;
              webhookSecretFile = config.security.nix-secrets.secrets."nixbot/github-webhook-secret".path;
              oauthId = cfg.githubOauthId;
              oauthSecretFile = config.security.nix-secrets.secrets."nixbot/github-oauth-secret".path;
              repoAllowlist = [ cfg.repository ];
              topic = null;
            };

            prApproval = {
              enable = true;
              # Not CONTRIBUTOR, because one merged commit shouldn't skip approval.
              trustedAssociations = [
                "OWNER"
                "MEMBER"
                "COLLABORATOR"
              ];
            };

            uploaders = [
              {
                name = "attic";
                command = [ (lib.getExe pushToCache) ];
                pathsVia = "stdin";
              }
            ];

            # Without gcroots, GC deletes its kernel build before it lands on master.
            branches.flake-lock-update = {
              matchGlob = "update_flake_lock_action";
              registerGCRoots = true;
            };
          };

          systemd = {
            # Upstream binds every interface when nginx is off.
            sockets.nixbot.socketConfig.ListenStream = lib.mkForce "${cfg.listenAddress}:${toString config.services.nixbot.port}";

            services.nixbot.serviceConfig.MemoryMax = "7G";

            services.nixbot.preStart = ''
              install -d -m 700 ${stateDir}/.ssh
              install -m 600 ${fetchSshConfig} ${stateDir}/.ssh/config
            '';
          };
        };
      };

    persistence =
      { config, ... }:
      {
        environment.persistence.${config.modules.persistence.persistDir}.directories =
          lib.mkIf (config.services.nixbot.enable or false)
            [
              {
                directory = stateDir;
                user = "nixbot";
                group = "nixbot";
                mode = "0700";
              }
              {
                directory = postgresDir;
                user = "postgres";
                group = "postgres";
                mode = "0750";
              }
            ];
      };
  };
}
