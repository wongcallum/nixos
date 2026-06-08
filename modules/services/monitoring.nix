{
  flake.modules.nixos.monitoring =
    { config, ... }:
    {
      services.grafana = {
        enable = true;
        dataDir = config.utils.dataDir "grafana";
        settings = {
          server = {
            http_addr = "127.0.0.1";
            http_port = 2342;
            domain = "grafana.${config.modules.gateway.tld}";
          };
          # internal
          security.secret_key = "SW2YcwTIb9zpOOhoPsMm";
          auth.disable_login_form = false;
          "auth.anonymous" = {
            enabled = true;
            org_name = "Main Org.";
            org_role = "Viewer";
          };
        };
      };

      fileSystems."/var/lib/${config.services.prometheus.stateDir}" = {
        device = config.utils.dataDir "prometheus2";
        fsType = "none";
        options = [ "bind" ];
      };

      services.prometheus = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9001;
        exporters = {
          node = {
            enable = true;
            enabledCollectors = [
              "logind"
              "processes"
              "systemd"
              "tcpstat"
            ];
            port = 9002;
          };
          smartctl = {
            enable = true;
            port = 9003;
          };
          zfs = {
            enable = true;
            port = 9004;
          };
        };
        scrapeConfigs =
          map
            (exporter: {
              job_name = "local_${exporter}";
              static_configs = [
                {
                  targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.${exporter}.port}" ];
                  # Override the default `host:port` instance label with the
                  # hostname so alerts/dashboards read "liz" instead of an IP.
                  labels.instance = config.networking.hostName;
                }
              ];
            })
            [
              "node"
              "smartctl"
              "zfs"
            ];
      };
    };

  flake.modules.nixos.gateway =
    { config, lib, ... }:
    {
      modules.gateway.services.monitoring-grafana = lib.mkIf config.services.grafana.enable {
        name = "Grafana";
        domainName = "grafana";
        addr = "${toString config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/grafana.png";
        category = "Administration";
      };

      modules.gateway.services.monitoring-prometheus = lib.mkIf config.services.prometheus.enable {
        name = "Prometheus";
        domainName = "prometheus";
        addr = "${toString config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/prometheus.png";
        category = "Administration";
      };
    };
}
