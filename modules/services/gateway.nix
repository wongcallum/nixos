{ lib, inputs, ... }:
{
  # requires flake.modules.nixos.sops
  flake.modules.nixos.gateway =
    { config, pkgs, ... }:
    let
      caddyDataDir = config.utils.dataDir "caddy";
      fqdn = domainName: "${domainName}.${config.gateway.tld}";
      prismTowerPkg = inputs.prism-tower.lib.mkPrismTower {
        inherit pkgs;
        services = config.services.prism-tower.services;
      };
    in
    {
      imports = [ inputs.prism-tower.nixosModules.default ];

      options.gateway = {
        tld = lib.mkOption {
          type = lib.types.str;
          default = "staging.7sref";
        };
        localServices = lib.mkOption {
          type = lib.types.listOf (
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
          default = [ ];
          description = "Service metadata for reverse proxy and dashboard";
        };
      };

      config = {
        gateway.localServices = [
          {
            name = "Technitium DNS";
            domainName = "technitium";
            iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/technitium.png";
            addr = "127.0.0.1:5380";
            category = "Administration";
          }
        ];

        systemd.tmpfiles.rules = [
          "d ${caddyDataDir} 0750 caddy caddy -"
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

        fileSystems."/var/lib/technitium-dns-server" = {
          device = config.utils.dataDir "technitium-dns-server";
          options = [ "bind" ];
        };

        services.technitium-dns-server.enable = true;
        systemd.services.technitium-dns-server.serviceConfig = {
          WorkingDirectory = lib.mkForce null;
          BindPaths = lib.mkForce null;
          DynamicUser = lib.mkForce false;
          User = "root";
          Group = "root";
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
              }) config.gateway.localServices
            ))
            // {
              "http://${fqdn "prism.tower"}, https://${fqdn "prism.tower"}" = {
                extraConfig = ''
                  tls {
                    issuer internal {
                      ca 7sref_ca
                    }
                  }
                  root * ${prismTowerPkg}
                  file_server
                '';
              };
            };
        };

        services.prism-tower = {
          enable = true;
          services = map (service: {
            name = service.name;
            url = "https://${fqdn service.domainName}";
            iconUrl = service.iconUrl;
            category = service.category;
          }) (builtins.filter (service: !service.hidden) config.gateway.localServices);
        };
      };
    };
}
