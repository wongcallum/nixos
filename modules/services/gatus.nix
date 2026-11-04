{ lib, ... }:
let
  host = "eberouge";
  port = 8080;
  tokenSecret = "grafana/telegram-bot-token";
  chatId = "5603246758";

  heartbeat = {
    group = "liz";
    name = "grafana-heartbeat";
    # Tailnet-only, and it can only fake a heartbeat, so it needn't be secret.
    token = "eberouge-heartbeat-a83f1c0e";
  };
  heartbeatUrl =
    addr:
    "http://${addr}:${toString port}/api/v1/endpoints/${heartbeat.group}_${heartbeat.name}/external?success=true";

  publicSites = [
    "gallery.callumwong.com"
    "ci.callumwong.com"
    "thsconline.callumwong.com"
  ];
in
{
  flake.modules.nixos = {
    gatus =
      { config, ... }:
      let
        alerts = [ { type = "telegram"; } ];
      in
      {
        sops.secrets.${tokenSecret}.restartUnits = [ "gatus.service" ];
        sops.templates."gatus.env" = {
          content = "TELEGRAM_TOKEN=${config.sops.placeholder.${tokenSecret}}";
          restartUnits = [ "gatus.service" ];
        };

        services.gatus = {
          enable = true;
          environmentFile = config.sops.templates."gatus.env".path;
          settings = {
            web.port = port;
            storage = {
              type = "sqlite";
              path = "/var/lib/gatus/data.db";
            };

            alerting.telegram = {
              token = "\${TELEGRAM_TOKEN}";
              id = chatId;
              default-alert = {
                failure-threshold = 3;
                success-threshold = 2;
                send-on-resolved = true;
              };
            };

            endpoints = [
              {
                name = "ping";
                group = "liz";
                url = "icmp://${config.modules.hostAddrs.liz}";
                interval = "1m";
                conditions = [ "[CONNECTED] == true" ];
                inherit alerts;
              }
              {
                name = "grafana";
                group = "liz";
                url = "https://grafana.${config.modules.gateway.tld}/api/health";
                interval = "1m";
                conditions = [ "[STATUS] == 200" ];
                inherit alerts;
              }
            ]
            ++ map (domain: {
              name = domain;
              group = "public";
              url = "https://${domain}";
              interval = "5m";
              conditions = [ "[STATUS] == 200" ];
              inherit alerts;
            }) publicSites;

            external-endpoints = [
              {
                inherit (heartbeat) name group token;
                heartbeat.interval = "15m";
                alerts = [
                  {
                    type = "telegram";
                    failure-threshold = 1;
                    description = "Grafana alerting on liz stopped sending heartbeats";
                  }
                ];
              }
            ];
          };
        };
      };

    persistence =
      { config, ... }:
      {
        environment.persistence.${config.modules.persistence.persistDir}.directories =
          lib.mkIf config.services.gatus.enable
            [ "/var/lib/private/gatus" ];
      };

    gateway =
      { config, ... }:
      {
        modules.gateway.services.monitoring-gatus = {
          name = "Gatus";
          domainName = "status";
          addr = "${config.modules.hostAddrs.${host}}:${toString port}";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/gatus.png";
          category = "Administration";
        };
      };

    # An always-firing rule, so silence means Grafana's alerting is down.
    monitoring =
      { config, ... }:
      {
        services.grafana.provision.alerting = {
          contactPoints.settings.contactPoints = [
            {
              orgId = 1;
              name = "gatus-heartbeat";
              receivers = [
                {
                  uid = "gatus-heartbeat";
                  type = "webhook";
                  disableResolveMessage = true;
                  settings = {
                    url = heartbeatUrl config.modules.hostAddrs.${host};
                    httpMethod = "POST";
                    authorization_scheme = "Bearer";
                    authorization_credentials = heartbeat.token;
                  };
                }
              ];
            }
          ];

          rules.settings.groups = [
            {
              orgId = 1;
              name = "heartbeat";
              folder = "Alerts";
              interval = "1m";
              rules = [
                {
                  uid = "gatus-heartbeat";
                  title = "Heartbeat";
                  condition = "C";
                  for = "0s";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = config.modules.monitoring.datasourceUids.prometheus;
                      relativeTimeRange = {
                        from = 600;
                        to = 0;
                      };
                      model = {
                        refId = "A";
                        expr = "vector(1)";
                        instant = true;
                        queryType = "instant";
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        refId = "C";
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [ 0 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  # Without Prometheus the heartbeat should stop, not become an error alert.
                  noDataState = "OK";
                  execErrState = "OK";
                  annotations.summary = "Always firing; Gatus on ${host} alerts when it stops";
                  notification_settings = {
                    receiver = "gatus-heartbeat";
                    group_interval = "1m";
                    repeat_interval = "5m";
                  };
                }
              ];
            }
          ];
        };
      };
  };
}
