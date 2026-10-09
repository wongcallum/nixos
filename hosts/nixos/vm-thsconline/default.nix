{
  config,
  lib,
  microvmLib,
  ...
}:
let
  inherit (config.flake.modules) nixos;
  inherit (config.flake) keys;

  domain = "thsconline.callumwong.com";
  port = 5000;
  mirror = "/mirror";
in
{
  flake.modules.nixos."hosts/nixos/vm-thsconline" =
    { pkgs, ... }:
    {
      imports = [
        (microvmLib.mkGuestModule {
          n = 3;
          hostname = "vm-thsconline";
        })
      ]
      ++ (with nixos; [
        persistence
        sops

        ssh

        cloudflared
      ]);

      system.stateVersion = "26.05";

      microvm = {
        vcpu = 2;
        mem = 1024;
        # virtiofsd on liz enforces readOnly, so the guest cannot write to the
        # mirror; the sync scripts and state in /tank/thsconline/_sync stay
        # outside the share
        shares = [
          {
            tag = "mirror";
            source = "/tank/thsconline/mirror";
            mountPoint = mirror;
            proto = "virtiofs";
            readOnly = true;
          }
        ];
      };

      users.users.root = {
        hashedPassword = "!";
        openssh.authorizedKeys.keys = keys.callum;
      };

      services.openssh.settings = {
        PermitRootLogin = lib.mkOverride 40 "prohibit-password";
        PasswordAuthentication = lib.mkOverride 40 false;
      };

      systemd.services.thsconline-listing = {
        description = "Public file listing of the THSC Online mirror";
        wantedBy = [ "multi-user.target" ];
        unitConfig.RequiresMountsFor = [ mirror ];
        serviceConfig = {
          ExecStart = lib.escapeShellArgs [
            (lib.getExe pkgs.dufs)
            "--bind"
            "127.0.0.1"
            "--port"
            (toString port)
            "--allow-search"
            mirror
          ];
          DynamicUser = true;
          Restart = "on-failure";
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
        };
      };

      modules.cloudflared = {
        # tunnelId and its credentials are still to be created
        credentialsSecret = "cloudflared/vm-thsconline-credentials.json";
        ingress.${domain} = "http://127.0.0.1:${toString port}";
      };
    };
}
