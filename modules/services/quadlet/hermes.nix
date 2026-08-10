let
  networkName = "hermes";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-hermes =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
      dataDir = config.utils.dataDir "hermes";
      shareGroup = if config.services.syncthing.enable then config.services.syncthing.group else "1000";
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      # owner matches HERMES_UID/HERMES_GID below
      #
      # docker/stage2-hook.sh runs `chown -R hermes:hermes` over subdirectories
      # when the top-level owner does not match HERMES_UID.
      #
      # 0710 lets syncthing access workspace/ without being able to read $HERMES_HOME
      # 2770 + setgid keeps files the agent creates group-owned and readable by it
      systemd.tmpfiles.rules = [
        "d ${dataDir} 0710 1000 ${shareGroup} -"
        "d ${dataDir}/workspace 2770 1000 ${shareGroup} -"
      ];

      modules.containers.hermes = lib.mkDefault true;

      virtualisation.quadlet = {
        autoUpdate.enable = true;

        networks.${networkName} = {
          networkConfig = {
            subnets = [ "172.30.0.0/16" ];
            disableDns = true;
          };
        };

        containers.hermes = lib.mkIf config.modules.containers.hermes (
          config.utils.mkContainer {
            containerConfig = {
              image = "docker.io/nousresearch/hermes-agent:latest";
              autoUpdate = "registry";
              exec = "gateway run";
              environments = {
                HERMES_UID = "1000";
                HERMES_GID = "1000";

                # bind to 0.0.0.0 fails unless an auth provider is configured
                # HERMES_DASHBOARD_BASIC_AUTH_USERNAME / _PASSWORD / _SECRET must be set in $HERMES_HOME/.env
                HERMES_DASHBOARD = "1";

                TERMINAL_CWD = "/opt/data/workspace";

                # if you ever enable the api server, set API_SERVER_ENABLED and API_SERVER_KEY
              };
              networks = [ networks.${networkName}.ref ];
              ip = "172.30.0.2";
              volumes = [ "${dataDir}:/opt/data" ];
              healthCmd = "curl -fsS -o /dev/null http://localhost:9119/ || exit 1";
              healthInterval = "30s";
              healthTimeout = "10s";
              healthRetries = 3;
              healthStartPeriod = "30s";
            };
          }
        );
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services.hermes = lib.mkIf config.modules.containers.hermes {
        name = "Hermes";
        domainName = "hermes";
        addr = "172.30.0.2:9119";
        iconUrl = "https://cdn.jsdelivr.net/gh/selfhst/icons/png/hermes-agent.png";
        category = "Productivity";
      };
    };
}
