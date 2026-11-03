{ lib, ... }:
{
  flake.modules.nixos.t3code =
    { config, pkgs, ... }:
    let
      cfg = config.modules.t3code;
      package = pkgs.t3code;
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
        environment.systemPackages = [
          package
          pkgs.git
        ];

        nix.settings = {
          extra-substituters = [ "https://cache.numtide.com" ];
          extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
        };

        # The desktop app's SSH setup otherwise downloads a generic release binary, which can't run on NixOS.
        systemd.tmpfiles.settings.t3code =
          let
            t3Dir = "${config.users.users.${cfg.user}.home}/.t3";
            dir = "${t3Dir}/runtime/versions/${package.version}";
            userDir.d = {
              inherit (cfg) user;
              mode = "0755";
            };
          in
          {
            ${t3Dir} = userDir;
            "${t3Dir}/runtime" = userDir;
            "${t3Dir}/runtime/versions" = userDir;
            "${dir}" = userDir;
            "${dir}/t3"."L+".argument = lib.getExe package;
            "${dir}/.install-complete"."f+" = {
              inherit (cfg) user;
              argument = package.version;
            };
          };

        # Mirrors the unit `t3 service install` writes, as a system unit so it runs without a login.
        systemd.services.t3code = {
          description = "T3 Code server";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          startLimitIntervalSec = 300;
          startLimitBurst = 5;
          # Agents need the user's tools, not the unit's minimal PATH.
          # Matches the interactive shell, so setup scripts get wrapped in its syntax.
          environment.SHELL = lib.getExe pkgs.fish;
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
