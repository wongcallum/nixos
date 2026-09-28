let
  networkName = "leafwiki";
  leafwikiIp = "172.26.0.2";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-leafwiki =
    { config, pkgs, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
      dataDir = config.utils.dataDir "leafwiki";
      secretFile = "${dataDir}/secret.env";

      # LeafWiki refuses to start without a JWT secret and an initial admin
      # password. Generate both once and keep them out of the Nix store; the
      # admin password only seeds the first admin account.
      prepareLeafwiki = pkgs.writeShellApplication {
        name = "leafwiki-prepare";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          if [ ! -s ${lib.escapeShellArg secretFile} ]; then
            jwt="$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')"
            password="$(od -An -tx1 -N12 /dev/urandom | tr -d ' \n')"
            umask 077
            printf 'LEAFWIKI_JWT_SECRET=%s\nLEAFWIKI_ADMIN_PASSWORD=%s\n' "$jwt" "$password" > ${lib.escapeShellArg secretFile}
          fi
        '';
      };
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${dataDir} 0700 1000 1000 -"
        "d ${dataDir}/data 0700 1000 1000 -"
      ];

      modules.containers.leafwiki = lib.mkDefault true;

      virtualisation.quadlet = {
        networks.${networkName} = {
          networkConfig = {
            subnets = [ "172.26.0.0/16" ];
            disableDns = true;
            options.isolate = "strict";
          };
        };

        containers = {
          leafwiki = lib.mkIf config.modules.containers.leafwiki (
            config.utils.mkContainer {
              containerConfig = {
                image = "ghcr.io/perber/leafwiki:v0.13.0@sha256:c40904dafd9db81ca2c9334e8c67fb168d175876111fc1fd9a00e3715b66775b";
                user = "1000:1000";
                environments = {
                  LEAFWIKI_ENABLE_REVISION = "true";
                  LEAFWIKI_ENABLE_LINK_REFACTOR = "true";
                };
                environmentFiles = [ secretFile ];
                networks = [ networks.${networkName}.ref ];
                ip = leafwikiIp;
                volumes = [ "${dataDir}/data:/app/data" ];
              };
              serviceConfig = {
                ExecStartPre = lib.getExe prepareLeafwiki;
              };
            }
          );
        };
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services.leafwiki = lib.mkIf config.modules.containers.leafwiki {
        name = "LeafWiki";
        domainName = "wiki";
        addr = "${leafwikiIp}:8080";
        iconUrl = "https://cdn.jsdelivr.net/gh/perber/leafwiki@v0.13.0/ui/leafwiki-ui/public/favicon.svg";
        category = "Productivity";
      };
    };
}
