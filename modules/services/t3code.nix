{ lib, inputs, ... }:
{
  flake.modules.nixos.t3code =
    { config, pkgs, ... }:
    let
      cfg = config.modules.t3code;
      agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
      package = agents.t3code.override { providerPackages = [ agents.claude-code ]; };
    in
    {
      options.modules.t3code = {
        user = lib.mkOption {
          type = lib.types.str;
          default = "callum";
          description = "User the server and its agents run as";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 3773;
        };
      };

      config = {
        environment.systemPackages = [ package ];

        # Mirrors the unit `t3 service install` writes, as a system unit so it runs without a login.
        systemd.services.t3code = {
          description = "T3 Code server";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          startLimitIntervalSec = 300;
          startLimitBurst = 5;
          # Agents need the user's tools, not the unit's minimal PATH.
          environment.PATH = lib.mkForce (
            lib.concatStringsSep ":" [
              "/run/wrappers/bin"
              "/etc/profiles/per-user/${cfg.user}/bin"
              "/run/current-system/sw/bin"
            ]
          );
          serviceConfig = {
            User = cfg.user;
            WorkingDirectory = "~";
            # --lan binds every interface; the firewall leaves only the tailnet open.
            ExecStart = "${lib.getExe package} serve --lan --port ${toString cfg.port}";
            KillMode = "mixed";
            OOMPolicy = "continue";
            Restart = "always";
            RestartSec = 5;
            CPUWeight = 1000;
            IOWeight = 1000;
            MemoryLow = "1536M";
            OOMScoreAdjust = 100;
            ManagedOOMPreference = "avoid";
          };
        };
      };
    };
}
