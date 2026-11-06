{ lib, inputs, ... }:
{
  flake.modules.nixos.gateway =
    { config, pkgs, ... }:
    let
      caddyDataDir = config.utils.dataDir "caddy";
      fqdn = domainName: "${domainName}.${config.modules.gateway.tld}";
      reverseProxyConfig =
        service:
        let
          body =
            lib.optionalString service.tlsInsecureSkipVerify ''
              transport http {
                tls_insecure_skip_verify
              }
            ''
            + service.reverseProxyExtraConfig;
        in
        lib.optionalString (body != "") " {\n${body}}";
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
      # Serve plain HTTP too, for devices that can't install the internal CA.
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
                reverseProxyExtraConfig = lib.mkOption {
                  type = lib.types.lines;
                  default = "";
                  description = "Extra directives for this service's reverse_proxy block";
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

        systemd.tmpfiles.rules = [
          "d ${caddyDataDir} 0750 caddy caddy -"
        ];

        security.nix-secrets.secrets."caddy/ca.pem" = {
          owner = "caddy";
          mode = "0440";
        };

        security.nix-secrets.secrets."caddy/ca.key".owner = "caddy";

        services.blocky = {
          enable = true;
          settings = {
            upstreams.groups.default = [
              "https://1.1.1.1/dns-query"
              "https://1.0.0.1/dns-query"
            ];
            customDNS.mapping.${config.modules.gateway.tld} = config.modules.hostAddrs.liz;
            blocking = {
              denylists.ads = [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" ];
              clientGroupsBlock.default = [ "ads" ];
              blockType = "nxDomain";
            };
            caching.prefetching = true;
            queryLog.type = "none";
          };
        };

        # vhosts are keyed by domain, so a clash would silently merge two sites.
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
                  cert ${config.security.nix-secrets.secrets."caddy/ca.pem".path}
                  key ${config.security.nix-secrets.secrets."caddy/ca.key".path}
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
                    # TODO: derive this from the config.
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
