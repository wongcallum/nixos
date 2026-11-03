{ inputs, lib, ... }:
{
  flake.modules.nixos.cliproxyapi =
    { config, pkgs, ... }:
    let
      cfg = config.modules.cliproxyapi;
      port = 8317;
      stateDir = "/var/lib/cliproxyapi";
      accessKey = "${stateDir}/access-key";
      upstream = inputs.unstable-upstream;
      upstreamModule = import "${upstream}/nixos/modules/services/misc/cliproxyapi.nix";
    in
    {
      # workaround: cliproxyapi-backport
      # Without meta.doc: stable's manual has no redirects for its anchors and fails to build.
      imports = [
        (lib.setFunctionArgs (args: removeAttrs (upstreamModule args) [ "meta" ]) (
          lib.functionArgs upstreamModule
        ))
      ];

      options.modules.cliproxyapi.clients = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "shama"
          "acid"
          "salt"
        ];
        description = "Hosts in modules.hostAddrs allowed to reach CLIProxyAPI";
      };

      config = {
        sops.secrets."cliproxyapi/management-key" = { };

        services.cliproxyapi = {
          enable = true;
          # workaround: cliproxyapi-backport
          package = upstream.legacyPackages.${pkgs.stdenv.hostPlatform.system}.cliproxyapi;
          settings = {
            server.port = port;
            management = {
              allow-remote = true;
              secret-key._secret = config.sops.secrets."cliproxyapi/management-key".path;
              disable-control-panel = true;
            };
            # With no client keys the proxy serves anyone; this one is never handed out.
            access.api-keys = [ { _secret = accessKey; } ];
            observability.logs.usage-statistics-enabled = false;
          };
        };

        systemd.services.cliproxyapi-access-key = {
          description = "Generate CLIProxyAPI's unused client key";
          requiredBy = [ "cliproxyapi.service" ];
          before = [ "cliproxyapi.service" ];
          unitConfig.ConditionPathExists = "!${accessKey}";
          serviceConfig.Type = "oneshot";
          script = ''
            install -d -m 700 ${stateDir}
            (umask 077; head -c 32 /dev/urandom | base64 -w0 > ${accessKey})
          '';
        };

        # The management key can act as the logged-in account, so only T3 hosts may connect.
        networking.firewall = {
          extraCommands = ''
            ip46tables -N cliproxyapi-fw 2>/dev/null || ip46tables -F cliproxyapi-fw
            ip46tables -A cliproxyapi-fw -i lo -j RETURN
            ${lib.concatMapStrings (host: ''
              iptables -A cliproxyapi-fw -s ${config.modules.hostAddrs.${host}} -j RETURN
            '') cfg.clients}
            ip46tables -A cliproxyapi-fw -j nixos-fw-refuse
            ip46tables -I nixos-fw -p tcp --dport ${toString port} -j cliproxyapi-fw
          '';
          extraStopCommands = ''
            ip46tables -D nixos-fw -p tcp --dport ${toString port} -j cliproxyapi-fw 2>/dev/null || true
            ip46tables -F cliproxyapi-fw 2>/dev/null || true
            ip46tables -X cliproxyapi-fw 2>/dev/null || true
          '';
        };

        environment.persistence.${config.modules.persistence.persistDir}.directories = [
          {
            directory = stateDir;
            user = "cliproxyapi";
            group = "cliproxyapi";
            mode = "0700";
          }
        ];
      };
    };
}
