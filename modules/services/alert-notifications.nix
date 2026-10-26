{
  flake.modules.nixos.monitoring =
    { config, pkgs, ... }:
    let
      tokenSecret = "grafana/telegram-bot-token";

      # Explore is closed to the anonymous viewer a phone gets, so alerts link
      # here instead, passing a rule's `logs` annotation as the query
      logsDashboard =
        let
          datasource = {
            type = "loki";
            uid = config.modules.monitoring.datasourceUids.loki;
          };
          defaultQuery = ''{job="systemd-journal"}'';
        in
        {
          uid = "alert-logs";
          title = "Alert logs";
          description = "Journal lines for the LogQL in the query box; Telegram alerts open it on the rule's logs";
          schemaVersion = 39;
          time = {
            from = "now-1h";
            to = "now";
          };
          templating.list = [
            {
              type = "textbox";
              name = "query";
              label = "LogQL";
              query = defaultQuery;
              current = {
                text = defaultQuery;
                value = defaultQuery;
              };
            }
          ];
          panels = [
            {
              type = "logs";
              title = "Logs";
              inherit datasource;
              gridPos = {
                x = 0;
                y = 0;
                w = 24;
                h = 30;
              };
              targets = [
                {
                  refId = "A";
                  inherit datasource;
                  # raw, so Grafana passes the query through without escaping it
                  expr = "\${query:raw}";
                  queryType = "range";
                  maxLines = 2000;
                }
              ];
              options = {
                showTime = true;
                wrapLogMessage = true;
                sortOrder = "Descending";
                enableLogDetails = true;
                dedupStrategy = "none";
              };
            }
          ];
        };
    in
    {
      sops.secrets.${tokenSecret} = {
        owner = "grafana";
        restartUnits = [ "grafana.service" ];
      };

      # The contact point, policy and template first lived in the UI; keeping the
      # contact point UID and template name let provisioning take them over in place.
      services.grafana.provision.alerting = {
        contactPoints.settings = {
          apiVersion = 1;
          contactPoints = [
            {
              orgId = 1;
              name = "telegram";
              receivers = [
                {
                  uid = "efflrcjoowsg0c";
                  type = "telegram";
                  disableResolveMessage = false;
                  settings = {
                    # read by Grafana at startup, so the token stays out of the store
                    bottoken = "$__file{${config.sops.secrets.${tokenSecret}.path}}";
                    chatid = "5603246758";
                    message = ''{{ template "tg.message" . }}'';
                    parse_mode = "HTML";
                    disable_notification = false;
                    disable_web_page_preview = false;
                    protect_content = false;
                  };
                }
              ];
            }
          ];
        };

        policies.settings = {
          apiVersion = 1;
          policies = [
            {
              orgId = 1;
              receiver = "telegram";
              group_by = [
                "grafana_folder"
                "alertname"
              ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "999w";
            }
          ];
        };

        templates.settings = {
          apiVersion = 1;
          templates = [
            {
              orgId = 1;
              name = "My Templates";
              template =
                builtins.replaceStrings
                  [ "@logsUrl@" ]
                  [ "https://${config.services.grafana.settings.server.domain}/d/${logsDashboard.uid}" ]
                  (builtins.readFile ./telegram-alerts.gotmpl);
            }
          ];
        };
      };

      services.grafana.provision.dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "alert-logs";
            folder = "Alerts";
            options.path = pkgs.writeTextDir "alert-logs.json" (builtins.toJSON logsDashboard);
          }
        ];
      };
    };
}
