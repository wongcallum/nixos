{
  flake.modules.nixos.monitoring =
    { config, ... }:
    {
      services.grafana = {
        enable = true;
        settings.server = {
          domain = "grafana.7sref";
          http_addr = "127.0.0.1";
          http_port = 2342;
        };
        dataDir = config.utils.dataDir "grafana";
      };

      fileSystems."/var/lib/${config.services.prometheus.stateDir}" = {
        device = config.utils.dataDir "prometheus2";
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
    { config, ... }:
    {
      modules.gateway.localServices = [
        {
          name = "Grafana";
          domainName = "grafana";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/grafana.png";
          addr = "${toString config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}";
          category = "Monitoring";
        }
        {
          name = "Prometheus";
          domainName = "prometheus";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/prometheus.png";
          addr = "${toString config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          category = "Monitoring";
        }
      ];
    };
}
