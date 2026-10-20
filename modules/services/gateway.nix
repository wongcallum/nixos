{ lib, inputs, ... }:
{
  # requires flake.modules.nixos.sops
  flake.modules.nixos.gateway =
    { config, pkgs, ... }:
    let
      caddyDataDir = config.utils.dataDir "caddy";
      technitiumDataDir = config.utils.dataDir "technitium";
      fqdn = domainName: "${domainName}.${config.modules.gateway.tld}";
      reverseProxyConfig =
        service:
        lib.optionalString service.tlsInsecureSkipVerify ''
          {
            transport http {
              tls_insecure_skip_verify
            }
          }
        '';
      serviceConfig =
        service:
        if service.staticRoot != null then
          ''
            root * ${service.staticRoot}
            file_server
          ''
        else
          "reverse_proxy ${service.addr}${reverseProxyConfig service}";
      gatewayServices = builtins.attrValues config.modules.gateway.services;
      # serve plain http too, for devices that can't install the internal CA
      mkVhost = domainName: body: {
        "http://${fqdn domainName}, https://${fqdn domainName}".extraConfig = ''
          tls {
            issuer internal {
              ca 7sref_ca
            }
          }
          ${body}
        '';
      };
    in
    {
      options.modules.gateway = {
        services = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                };
                domainName = lib.mkOption {
                  type = lib.types.str;
                };
                addr = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                staticRoot = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  default = null;
                  description = "Static content root for this service";
                };
                tlsInsecureSkipVerify = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Disable TLS certificate verification for this reverse-proxy upstream";
                };
                iconUrl = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                };
                category = lib.mkOption {
                  type = lib.types.str;
                  default = "Other";
                };
                hidden = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                };
              };
            }
          );
          default = { };
          description = "Registry of service metadata for reverse proxy and dashboard";
        };
      };

      config = {
        nixpkgs.overlays = [ inputs.prism-tower.overlays.default ];

        modules.gateway.services.technitium-dns = lib.mkIf config.services.technitium-dns-server.enable {
          name = "Technitium DNS";
          domainName = "technitium";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/technitium.png";
          addr = "127.0.0.1:5380";
          category = "Administration";
        };

        systemd.tmpfiles.rules = [
          "d ${caddyDataDir} 0750 caddy caddy -"
          "d ${technitiumDataDir} 0750 technitium-dns-server technitium-dns-server -"
        ];

        sops.secrets."caddy/ca.pem" = {
          owner = "caddy";
          mode = "0440";
        };

        sops.secrets."caddy/ca.key".owner = "caddy";

        services.technitium-dns-server.enable = true;

        # upstream runs the server as a DynamicUser with a StateDirectory, which
        # puts its state in /var/lib/private/technitium-dns-server. Swap to a
        # static system user so the state can live under persistDir/data.
        users.users.technitium-dns-server = {
          isSystemUser = true;
          group = "technitium-dns-server";
        };
        users.groups.technitium-dns-server = { };

        systemd.services.technitium-dns-server.serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = "technitium-dns-server";
          Group = "technitium-dns-server";
          # empty value resets the list, so no /var/lib entry is created
          StateDirectory = lib.mkForce "";
          ExecStart = lib.mkForce (
            "${config.services.technitium-dns-server.package}/bin/technitium-dns-server " + technitiumDataDir
          );
          # ProtectSystem = "strict" leaves persistDir read-only otherwise
          ReadWritePaths = [ technitiumDataDir ];
          # make sure we don't watch the entire root with inotify
          WorkingDirectory = lib.mkForce technitiumDataDir;
        };

        # vhosts are keyed by domain, so a clash would silently merge two sites
        assertions = [
          {
            assertion = lib.allUnique ([ "prism.tower" ] ++ map (s: s.domainName) gatewayServices);
            message = "modules.gateway.services: each domainName must be unique and not prism.tower";
          }
        ];

        networking.firewall = {
          allowedTCPPorts = [
            53
            80
            443
          ];
          # plain DNS is UDP first, TCP only for truncated/large responses
          allowedUDPPorts = [ 53 ];
        };

        services.caddy = {
          enable = true;
          user = "caddy";
          group = "caddy";
          globalConfig = ''
            storage file_system ${caddyDataDir}
            pki {
              ca 7sref_ca {
                name 7sref_ca
                root {
                  cert ${config.sops.secrets."caddy/ca.pem".path}
                  key ${config.sops.secrets."caddy/ca.key".path}
                }
              }
            }
            skip_install_trust
            auto_https disable_redirects
          '';
          virtualHosts = lib.mkMerge (
            map (service: mkVhost service.domainName (serviceConfig service)) gatewayServices
            ++ [
              (mkVhost "prism.tower" ''
                root * ${
                  pkgs.prism-tower.override {
                    services = map (service: {
                      inherit (service) name iconUrl category;
                      url = "https://${fqdn service.domainName}";
                    }) (builtins.filter (s: !s.hidden) gatewayServices);
                    links = [
                      {
                        name = "Sentral";
                        url = "https://fortstreeths.sentral.com.au/auth/portal";
                      }
                    ];
                    # TODO: derive this value from the config somehow
                    searchUrl = "https://${fqdn "search"}/search";
                  }
                }
                header /_astro/* Cache-Control "public, max-age=31536000, immutable"
                header /index.html Cache-Control "public, no-cache"
                file_server
              '')
            ]
          );
        };
      };
    };
}
