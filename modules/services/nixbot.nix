{ inputs, ... }:
{
  flake.modules.nixos = {
    # requires flake.modules.nixos.sops
    nixbot =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.modules.nixbot;

        # upstream hardcodes both and offers no option for them
        stateDir = "/var/lib/nixbot";
        postgresDir = "/var/lib/postgresql";

        inherit (config.modules.attic) cacheName;
        cacheUrl = config.modules.attic.endpoint;

        # The token is referenced by path, not inlined, so this file is safe in
        # the store. Written into a throwaway XDG_CONFIG_HOME per push because
        # the attic client only ever looks at $XDG_CONFIG_HOME/attic/config.toml.
        atticClientConfig = (pkgs.formats.toml { }).generate "attic-client-config.toml" {
          default-server = cacheName;
          servers.${cacheName} = {
            endpoint = cacheUrl;
            token-file = config.sops.secrets."attic/push-token".path;
          };
        };

        # nixbot feeds store paths on stdin and retries failed batches itself
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
      in
      {
        imports = [ inputs.nixbot.nixosModules.nixbot ];

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
            modules.nixbot.githubAppId / githubOauthId are unset, so nixbot
            cannot authenticate against GitHub. Create the app, then fill both values
            from its settings page.
          '';

          sops.secrets = {
            # read by systemd as root through LoadCredential
            "nixbot/github-app-key".restartUnits = [ "nixbot.service" ];
            "nixbot/github-webhook-secret".restartUnits = [ "nixbot.service" ];
            "nixbot/github-oauth-secret".restartUnits = [ "nixbot.service" ];

            # read directly by the attic client running as the service user
            "attic/push-token" = {
              owner = "nixbot";
              group = "nixbot";
              mode = "0400";
            };
          };

          services.nixbot = {
            enable = true;
            inherit (cfg) domain;
            admins = map (admin: "github:${admin}") cfg.admins;

            nginx.enable = false;
            useHTTPS = true;
            buildSystems = [ "x86_64-linux" ];

            # one build at a time, nixbot defaults to the core count
            buildConcurrency = 1;
            # Unlike buildbot, the eval budget (workers * size) is a hard cap.
            # A single host's toplevel peaks around 3.5 GiB (liz).
            evalWorkerCount = 1;
            evalMaxMemorySize = 5120;

            github = {
              enable = true;
              appId = cfg.githubAppId;
              appSecretKeyFile = config.sops.secrets."nixbot/github-app-key".path;
              webhookSecretFile = config.sops.secrets."nixbot/github-webhook-secret".path;
              oauthId = cfg.githubOauthId;
              oauthSecretFile = config.sops.secrets."nixbot/github-oauth-secret".path;
              repoAllowlist = [ cfg.repository ];
              # projects are enabled in the web UI instead
              topic = null;
            };

            # The repository is public: hold fork PRs until a maintainer
            # approves them, so strangers can't run builds (or fill attic).
            # Branches pushed to the repository itself always build.
            prApproval = {
              enable = true;
              # not CONTRIBUTOR: one merged commit shouldn't skip approval
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

            # PR builds don't get gcroots by default, so the flake-lock-update
            # bot's branch would otherwise pay for a full kernel rebuild twice:
            # once on the PR, again when it lands on master with nothing cached.
            branches.flake-lock-update = {
              matchGlob = "update_flake_lock_action";
              registerGCRoots = true;
            };
          };

          systemd = {
            # upstream binds the port on every interface when nginx is off
            sockets.nixbot.socketConfig.ListenStream = lib.mkForce "${cfg.listenAddress}:${toString config.services.nixbot.port}";

            # evaluation workers plus the service itself; builds run in the nix daemon
            services.nixbot.serviceConfig.MemoryMax = "7G";
          };

          environment.persistence.${config.modules.persistence.persistDir}.directories = [
            # repository mirrors, build logs and the workload identity key
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
  };
}
