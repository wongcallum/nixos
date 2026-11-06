let
  port = 4242;
in
{
  flake.modules.nixos.kanzo =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      dataDir = config.utils.dataDir "kanzo";
      package = pkgs.kanzo;
    in
    {
      modules.kanzo.enable = lib.mkDefault true;

      users = lib.mkIf config.modules.kanzo.enable {
        users.kanzo = {
          isSystemUser = true;
          group = "kanzo";
        };
        groups.kanzo = { };
      };

      systemd = lib.mkIf config.modules.kanzo.enable {
        tmpfiles.rules = [
          "d ${dataDir} 0750 kanzo kanzo -"
        ];

        services.kanzo = {
          description = "Kanzo board";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          path = [ pkgs.git ];
          serviceConfig = {
            User = "kanzo";
            Group = "kanzo";
            ExecStart = "${lib.getExe package} --no-open --home ${dataDir} --port ${toString port}";
            Restart = "always";
            RestartSec = 5;
          };
        };
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services.kanzo = lib.mkIf config.modules.kanzo.enable {
        name = "Kanzo";
        domainName = "kanzo";
        addr = "127.0.0.1:${toString port}";
        # Kanzo only answers requests addressed to localhost, against DNS rebinding.
        reverseProxyExtraConfig = ''
          header_up Host localhost:${toString port}
          header_up Origin ^https?://${lib.escapeRegex "kanzo.${config.modules.gateway.tld}"}$ http://localhost:${toString port}
        '';
        iconUrl = "https://raw.githubusercontent.com/emanuele-em/kanzo/master/src/logo.png";
        category = "Productivity";
      };
    };
}
