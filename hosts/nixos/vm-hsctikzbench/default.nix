{
  config,
  inputs,
  lib,
  microvmLib,
  ...
}:
let
  inherit (config.flake.modules) nixos;
  inherit (config.flake) keys;

  domain = "hsctikzbench.callumwong.com";
  port = 8787;
  user = "hsctikzbench";
in
{
  flake.nixpkgs.vm-hsctikzbench = "unstable";

  flake.modules.nixos."hosts/nixos/vm-hsctikzbench" =
    { config, pkgs, ... }:
    let
      inherit (inputs.hsctikzbench.packages.${pkgs.stdenv.hostPlatform.system})
        hsctikzbench
        renderer
        ;

      dataDir = config.utils.dataDir user;
      cacheDir = "/var/cache/${user}";

      cliEnv = {
        HSCTIKZBENCH_DATA_DIR = dataDir;
        HSCTIKZBENCH_RENDERER = "local";
        HOME = cacheDir;
      };

      cli = pkgs.writeShellScriptBin "hsctikzbench" ''
        exec ${lib.getExe' pkgs.util-linux "runuser"} -u ${user} -- \
          ${lib.getExe' pkgs.coreutils "env"} \
            PATH=${lib.makeBinPath [ renderer ]}:"$PATH" \
            ${
              lib.concatStringsSep " " (
                lib.mapAttrsToList (name: value: "${name}=${lib.escapeShellArg value}") cliEnv
              )
            } \
            ${lib.getExe' hsctikzbench "hsctikzbench"} "$@"
      '';
    in
    {
      imports = [
        (microvmLib.mkGuestModule {
          n = 4;
          hostname = "vm-hsctikzbench";
        })
      ]
      ++ (with nixos; [
        persistence
        sops

        ssh

        cloudflared
      ]);

      system.stateVersion = "26.05";

      users = {
        users.${user} = {
          isSystemUser = true;
          group = user;
          home = dataDir;
        };
        groups.${user} = { };
        users.root = {
          hashedPassword = "!";
          openssh.authorizedKeys.keys = keys.callum;
        };
      };

      services.openssh.settings = {
        PermitRootLogin = lib.mkOverride 40 "prohibit-password";
        PasswordAuthentication = lib.mkOverride 40 false;
      };

      systemd.tmpfiles.rules = [
        "d ${dataDir} 0750 ${user} ${user} -"
        "d ${cacheDir} 0750 ${user} ${user} -"
      ];

      sops.secrets."hsctikzbench/env" = {
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = [ "hsctikzbench.service" ];
      };

      systemd.services.hsctikzbench = {
        description = "HSCTikZBench";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        environment = cliEnv // {
          HOST = "127.0.0.1";
          PORT = toString port;
          PUBLIC_URL = "https://${domain}";
          DATA_DIR = dataDir;
        };
        path = [ renderer ];

        serviceConfig = {
          ExecStart = lib.getExe' hsctikzbench "hsctikzbench-web";
          EnvironmentFile = config.sops.secrets."hsctikzbench/env".path;
          User = user;
          Group = user;
          WorkingDirectory = dataDir;
          Restart = "always";
          RestartSec = 10;
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          ReadWritePaths = [
            dataDir
            cacheDir
          ];
        };
      };

      environment.systemPackages = [ cli ];

      modules.cloudflared = {
        tunnelId = "11f4f67f-ec70-4088-afcd-a9cebe6b0cc5";
        credentialsSecret = "cloudflared/vm-hsctikzbench-credentials.json";
        ingress.${domain} = "http://127.0.0.1:${toString port}";
      };
    };
}
