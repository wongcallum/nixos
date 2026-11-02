let
  networkName = "productivity";
  valkeyIp = "172.22.0.2";
  searxngIp = "172.22.0.3";
in
{ inputs, lib, ... }:
{
  flake.modules.nixos.quadlet-productivity =
    { config, pkgs, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;

      searxngDir = config.utils.dataDir "searxng";
      secretFile = "${searxngDir}/secret.env";

      settingsFile = (pkgs.formats.yaml { }).generate "searxng-settings.yml" {
        use_default_settings = true;

        server = {
          limiter = false;
          public_instance = false;
        };

        # shares engine session tokens across workers, avoiding rate limits
        valkey.url = "valkey://${valkeyIp}:6379/0";

        outgoing = {
          # Mojeek takes ~1.5s from here and silently drops out under load
          request_timeout = 5.0;
          max_request_timeout = 12.0;
        };

        # upstream's only enabled engines all CAPTCHA or rate-limit this IP
        engines = [
          {
            name = "mojeek";
            disabled = false;
          }
          {
            name = "bing";
            disabled = false;
          }
          {
            name = "google";
            inactive = false;
          }
          # its handshake CAPTCHAs, suspending it for an hour
          {
            name = "startpage";
            disabled = true;
          }
        ];
      };

      # the image only writes settings.yml when missing, so it would never update
      prepareSearxng = pkgs.writeShellApplication {
        name = "searxng-prepare";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          if [ ! -s ${lib.escapeShellArg secretFile} ]; then
            secret="$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')"
            umask 077
            printf 'SEARXNG_SECRET=%s\n' "$secret" > ${lib.escapeShellArg secretFile}
          fi

          install -m 0644 ${settingsFile} ${lib.escapeShellArg "${searxngDir}/settings.yml"}
          rm -f ${lib.escapeShellArg "${searxngDir}/settings.yml.new"}
        '';
      };
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      systemd.tmpfiles.rules = [
        "d ${searxngDir} 0755 root root -"
      ];

      modules.containers = {
        searxng = lib.mkDefault true;
      };

      virtualisation.quadlet = {
        autoUpdate.enable = true;

        networks.${networkName} = {
          networkConfig = {
            subnets = [ "172.22.0.0/16" ];
            disableDns = true;
          };
        };

        containers = {
          searxng-valkey = lib.mkIf config.modules.containers.searxng (
            config.utils.mkContainer {
              containerConfig = {
                image = "docker.io/valkey/valkey:9@sha256:3b55fbaa0cd93cf0d9d961f405e4dfcc70efe325e2d84da207a0a8e6d8fde4f9";
                # bare and last: quadlet drops `--save ""` and every flag after it
                exec = "valkey-server --appendonly no --maxmemory 128mb --maxmemory-policy allkeys-lru --save";
                networks = [ networks.${networkName}.ref ];
                ip = valkeyIp;
                healthCmd = "valkey-cli ping";
                healthInterval = "5s";
                healthTimeout = "5s";
                healthRetries = 5;
                notify = "healthy";
              };
            }
          );

          searxng = lib.mkIf config.modules.containers.searxng (
            config.utils.mkContainer {
              containerConfig = {
                image = "docker.io/searxng/searxng:latest";
                autoUpdate = "registry";
                volumes = [ "${searxngDir}:/etc/searxng:rw" ];
                environmentFiles = [ secretFile ];
                networks = [ networks.${networkName}.ref ];
                ip = searxngIp;
                dropCapabilities = [ "ALL" ];
                addCapabilities = [
                  "CHOWN"
                  "SETGID"
                  "SETUID"
                  "DAC_OVERRIDE"
                ];
              };
              serviceConfig = {
                ExecStartPre = lib.getExe prepareSearxng;
              };
              unitConfig = {
                Requires = [ "searxng-valkey.service" ];
                After = [ "searxng-valkey.service" ];
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
        productivity-searxng = lib.mkIf config.modules.containers.searxng {
          name = "SearXNG";
          domainName = "search";
          addr = "${searxngIp}:8080";
          hidden = true;
        };
      };
    };
}
