{ lib, inputs, ... }:
{
  # requires flake.modules.nixos.sops
  flake.modules.nixos.gateway =
    { config, pkgs, ... }:
    let
      caddyDataDir = config.utils.dataDir "caddy";
      technitiumDataDir = config.utils.dataDir "technitium";
      fqdn = domainName: "${domainName}.${config.modules.gateway.tld}";
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
                  type = lib.types.str;
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
          group = "caddy";
          mode = "0440";
        };

        sops.secrets."caddy/ca.key" = {
          owner = "caddy";
          group = "caddy";
          mode = "0400";
        };

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
          WorkingDirectory = technitiumDataDir;
        };

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
          # for devices where we are unable to install CA, use http
          virtualHosts =
            (builtins.listToAttrs (
              map (service: {
                name = "http://${fqdn service.domainName}, https://${fqdn service.domainName}";
                value = {
                  extraConfig = ''
                    tls {
                      issuer internal {
                        ca 7sref_ca
                      }
                    }
                    reverse_proxy ${service.addr}
                  '';
                };
              }) (builtins.attrValues config.modules.gateway.services)
            ))
            // {
              "http://${fqdn "prism.tower"}, https://${fqdn "prism.tower"}" = {
                extraConfig = ''
                  tls {
                    issuer internal {
                      ca 7sref_ca
                    }
                  }
                  root * ${
                    pkgs.prism-tower.override {
                      services = map (service: {
                        inherit (service) name iconUrl category;
                        url = "https://${fqdn service.domainName}";
                      }) (builtins.filter (s: !s.hidden) (builtins.attrValues config.modules.gateway.services));
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
                '';
              };
            };
        };
      };
    };
}
