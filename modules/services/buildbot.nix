{ inputs, ... }:
{
  flake.modules.nixos = {
    # requires flake.modules.nixos.sops
    buildbot =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.modules.buildbot;

        masterHome = config.utils.dataDir "buildbot";
        # upstream hardcodes this and offers no option for it
        workerHome = "/var/lib/buildbot-worker";

        inherit (config.modules.attic) cacheName;
        cacheUrl = "https://${config.modules.attic.domainName}.${config.modules.gateway.tld}/";

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

        pushToCache = pkgs.writeShellApplication {
          name = "buildbot-attic-push";
          runtimeInputs = [
            pkgs.attic-client
            pkgs.coreutils
          ];
          text = ''
            if [ -z "''${OUT_PATH:-}" ]; then
              echo "no out_path for this build, nothing to push"
              exit 0
            fi

            config_home="$(mktemp -d)"
            trap 'rm -rf "$config_home"' EXIT
            install -Dm600 ${atticClientConfig} "$config_home/attic/config.toml"

            XDG_CONFIG_HOME="$config_home" attic push --jobs 4 ${cacheName} "$OUT_PATH"
          '';
        };
      in
      {
        imports = [
          inputs.buildbot-nix.nixosModules.buildbot-master
          inputs.buildbot-nix.nixosModules.buildbot-worker
        ];

        options.modules.buildbot = {
          domain = lib.mkOption {
            type = lib.types.str;
            example = "buildbot.example.com";
            description = "Public hostname the web interface is reached at";
          };

          repository = lib.mkOption {
            type = lib.types.str;
            example = "owner/repo";
            description = "The only repository CI is allowed to build";
          };

          topic = lib.mkOption {
            type = lib.types.str;
            default = "build-with-buildbot";
            description = "Repository topic that must be present for buildbot to build it";
          };

          admins = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "GitHub usernames allowed to log in, trigger builds and change settings";
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
            modules.buildbot.githubAppId / githubOauthId are unset, so buildbot
            cannot authenticate against GitHub. Create the app, then fill both values
            from its settings page.
          '';

          sops.secrets = {
            # read by systemd as root through LoadCredential
            "buildbot/github-app-key".restartUnits = [ "buildbot-master.service" ];
            "buildbot/github-webhook-secret".restartUnits = [ "buildbot-master.service" ];
            "buildbot/github-oauth-secret".restartUnits = [ "buildbot-master.service" ];
            # {"workers":[{"name":"liz","cores":1,"pass":"<same as worker-password>"}]}
            "buildbot/workers".restartUnits = [ "buildbot-master.service" ];
            "buildbot/worker-password".restartUnits = [ "buildbot-worker.service" ];

            # read directly by the attic client running as the worker user
            "attic/push-token" = {
              owner = "buildbot-worker";
              group = "buildbot-worker";
              mode = "0400";
            };
          };

          services = {
            buildbot-nix.master = {
              enable = true;
              inherit (cfg) domain admins;

              enableNginx = false;
              useHTTPS = true;
              accessMode.public = { };
              dbUrl = "sqlite:///state.sqlite";
              buildSystems = [ "x86_64-linux" ];

              # buildbot-nix scales eval workers with core count at 4 GiB each
              evalWorkerCount = 2;
              evalMaxMemorySize = 2048;

              workersFile = config.sops.secrets."buildbot/workers".path;

              github = {
                enable = true;
                appId = cfg.githubAppId;
                appSecretKeyFile = config.sops.secrets."buildbot/github-app-key".path;
                webhookSecretFile = config.sops.secrets."buildbot/github-webhook-secret".path;
                oauthId = cfg.githubOauthId;
                oauthSecretFile = config.sops.secrets."buildbot/github-oauth-secret".path;
                repoAllowlist = [ cfg.repository ];
                inherit (cfg) topic;
              };

              postBuildSteps = [
                {
                  name = "push to attic";
                  command = [ (lib.getExe pushToCache) ];
                  environment.OUT_PATH = inputs.buildbot-nix.lib.interpolate "%(prop:out_path)s";
                  # a cache upload failing does not mean the host stopped building
                  warnOnly = true;
                }
              ];
            };

            buildbot-nix.worker = {
              enable = true;
              workerPasswordFile = config.sops.secrets."buildbot/worker-password".path;
              # one build step at a time
              workers = 1;
            };

            buildbot-master = {
              home = lib.mkForce masterHome;
              listenAddress = "127.0.0.1";
            };

            postgresql.enable = lib.mkForce false;
          };

          systemd = {
            tmpfiles.rules = [
              "d ${masterHome} 0750 buildbot buildbot -"
              # `createHome` chowns the mount point before the bind mount is in
              # place, so the persisted directory has to be fixed up directly
              "d ${config.modules.persistence.persistDir}${workerHome} 0700 buildbot-worker buildbot-worker -"
            ];

            services.buildbot-master.serviceConfig.MemoryMax = "2G";
            services.buildbot-worker.serviceConfig.MemoryMax = "8G";
          };

          environment.persistence.${config.modules.persistence.persistDir}.directories = [
            {
              directory = workerHome;
              user = "buildbot-worker";
              group = "buildbot-worker";
              mode = "0700";
            }
          ];
        };
      };

    gateway =
      { config, lib, ... }:
      {
        modules.gateway.services.buildbot = lib.mkIf config.services.buildbot-master.enable {
          name = "Buildbot";
          domainName = "buildbot";
          iconUrl = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/buildbot.svg";
          addr = "127.0.0.1:${toString config.services.buildbot-master.port}";
          category = "Development";
        };
      };
  };
}
