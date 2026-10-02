{
  flake.modules.nixos.monitoring =
    { config, ... }:
    let
      tokenSecret = "grafana/telegram-bot-token";
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
              template = builtins.readFile ./telegram-alerts.gotmpl;
            }
          ];
        };
      };
    };
}
