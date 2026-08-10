let
  networkName = "ai";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-productivity =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${config.utils.dataDir "searxng"} 0755 root root -"
      ];

      modules.containers = {
        ai-searxng = lib.mkDefault true;
      };

      virtualisation.quadlet = {
        networks.${networkName} = {
          networkConfig = {
            subnets = [ "172.22.0.0/16" ];
            disableDns = true;
          };
        };

        containers = {
          ai-searxng = lib.mkIf config.modules.containers.ai-searxng (
            config.utils.mkContainer {
              containerConfig = {
                image = "searxng/searxng:latest";
                volumes = [ "${config.utils.dataDir "searxng"}:/etc/searxng:rw" ];
                networks = [ networks.${networkName}.ref ];
                ip = "172.22.0.3";
                dropCapabilities = [ "ALL" ];
                addCapabilities = [
                  "CHOWN"
                  "SETGID"
                  "SETUID"
                  "DAC_OVERRIDE"
                ];
              };
            }
          );

        };
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services = {
        productivity-searxng = lib.mkIf config.modules.containers.ai-searxng {
          name = "SearXNG";
          domainName = "search";
          addr = "172.22.0.3:8080";
          hidden = true;
        };
      };
    };
}
