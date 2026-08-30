let
  networkName = "ai";
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

      # `use_default_settings` is what keeps this file small: engine definitions
      # come from whichever image is running, so they can never drift behind it.
      # Only genuine local policy belongs here.
      settingsFile = (pkgs.formats.yaml { }).generate "searxng-settings.yml" {
        use_default_settings = true;

        server = {
          limiter = false;
          public_instance = false;
        };

        # Shared cache for engine session tokens (DuckDuckGo's vqd, Startpage's
        # sc_code). Without it every worker re-fetches them on every search,
        # which is itself a good way to get rate-limited.
        valkey.url = "valkey://${valkeyIp}:6379/0";

        outgoing = {
          # Mojeek answers in ~1.5s from this host, so the 3s upstream default
          # drops it under any load; results then silently go missing.
          request_timeout = 5.0;
          max_request_timeout = 12.0;
        };

        # Upstream ships every general web engine either `inactive` or
        # `disabled` except duckduckgo, startpage and brave -- all three of
        # which this host's IP is CAPTCHA'd or rate-limited by. Enable the ones
        # that actually answer from here so a block on one is survivable.
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
          # Its sc_code handshake redirects to a CAPTCHA, which suspends the
          # engine for an hour; the request is pure added latency.
          {
            name = "startpage";
            disabled = true;
          }
        ];
      };

      # The image writes settings.yml from its template only when the file is
      # missing, and never revisits it -- which is how the previous config
      # froze at the release that first created it. Reinstall on every start.
      # The secret stays out of the Nix store by living in the data dir.
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
                # Purely a cache: no persistence, and bounded so it cannot grow
                # into the host's memory.
                # `--save` must come last and take no argument. Its usual
                # `--save ""` form cannot survive quadlet, which drops the
                # empty argument and every flag after it; bare and trailing,
                # valkey reads it as an empty save list and snapshotting is off.
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
                image = "searxng/searxng:latest";
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
