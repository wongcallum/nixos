let
  networkName = "gotosocial";
  gotosocialIp = "172.31.0.2";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-gotosocial =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
      dataDir = config.utils.dataDir "gotosocial";
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${dataDir} 0700 1000 1000 -"
        "d ${dataDir}/cache 0700 1000 1000 -"
      ];

      modules.containers.gotosocial = lib.mkDefault true;

      virtualisation.quadlet = {
        networks.${networkName} = {
          networkConfig = {
            subnets = [ "172.31.0.0/16" ];
            disableDns = true;
            options.isolate = "strict";
          };
        };

        containers = {
          gotosocial = lib.mkIf config.modules.containers.gotosocial (
            config.utils.mkContainer {
              containerConfig = {
                image = "docker.io/superseriousbusiness/gotosocial:0.22.1@sha256:0078ca451dda5e8c4a8630784519f99b69f48c3dda79586a9703d4bf8ea14dae";
                user = "1000:1000";
                environments = {
                  GTS_HOST = "social.${config.modules.gateway.tld}";
                  GTS_DB_TYPE = "sqlite";
                  GTS_DB_ADDRESS = "/gotosocial/storage/sqlite.db";
                  GTS_LETSENCRYPT_ENABLED = "false";
                  GTS_INSTANCE_FEDERATION_MODE = "allowlist";
                  GTS_TRUSTED_PROXIES = "172.31.0.0/16";
                  GTS_WAZERO_COMPILATION_CACHE = "/gotosocial/.cache";
                };
                networks = [ networks.${networkName}.ref ];
                ip = gotosocialIp;
                volumes = [
                  "${dataDir}:/gotosocial/storage"
                  "${dataDir}/cache:/gotosocial/.cache"
                ];
              };
            }
          );

        };
      };
    };

  flake.modules.nixos.gateway =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      phanpy = pkgs.callPackage ../../../packages/phanpy { };
    in
    {
      modules.gateway.services = {
        gotosocial = lib.mkIf config.modules.containers.gotosocial {
          name = "GoToSocial";
          domainName = "social";
          addr = "172.31.0.2:8080";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/gotosocial.png";
          category = "Social";
        };

        phanpy = lib.mkIf config.modules.containers.gotosocial {
          name = "Phanpy";
          domainName = "phanpy";
          addr = null;
          staticRoot = phanpy;
          category = "Social";
        };
      };
    };
}
