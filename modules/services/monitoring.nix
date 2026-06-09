{
  flake.modules.nixos.monitoring =
    { config, lib, ... }:
    let
      exporterPorts = {
        node = 9002;
        smartctl = 9003;
        zfs = 9004;
        cadvisor = 9005;
      };
      lokiDir = config.utils.dataDir "loki";
      activeExporters = lib.unique (
        lib.concatMap (h: h.exporters) (lib.attrValues config.modules.metrics.hosts)
      );
      addrOf =
        host: if host == config.networking.hostName then "127.0.0.1" else config.modules.hostAddrs.${host};
      mkJob = exporter: {
        job_name = exporter;
        static_configs =
          lib.mapAttrsToList
            (host: _: {
              targets = [ "${addrOf host}:${toString exporterPorts.${exporter}}" ];
              labels.instance = host;
            })
            (
              lib.filterAttrs (_: hostCfg: builtins.elem exporter hostCfg.exporters) config.modules.metrics.hosts
            );
      };
    in
    {
      services = {
        grafana = {
          enable = true;
          dataDir = config.utils.dataDir "grafana";
          settings = {
            server = {
              http_addr = "127.0.0.1";
              http_port = 2342;
              domain = "grafana.${config.modules.gateway.tld}";
              root_url = "https://%(domain)s/";
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

        prometheus = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = 9001;
          scrapeConfigs = map mkJob activeExporters;
        };

        # https://keyruu.de/blog/monitoring/#loki
        loki = {
          enable = true;
          dataDir = lokiDir;
          configuration = {
            auth_enabled = false;
            server = {
              http_listen_address = "0.0.0.0";
              http_listen_port = 3100;
              grpc_listen_port = 9096;
              log_level = "warn";
            };
            common = {
              path_prefix = lokiDir;
              replication_factor = 1;
              ring = {
                instance_addr = "127.0.0.1";
                kvstore.store = "inmemory";
              };
            };
            schema_config.configs = [
              {
                from = "2024-01-01";
                store = "tsdb";
                object_store = "filesystem";
                schema = "v13";
                index = {
                  prefix = "index_";
                  period = "24h";
                };
              }
            ];
            storage_config.filesystem.directory = "${lokiDir}/chunks";
            compactor = {
              working_directory = "${lokiDir}/compactor";
              retention_enabled = true;
              delete_request_store = "filesystem";
            };
            limits_config.retention_period = "30d";
          };
        };
      };

      fileSystems."/var/lib/${config.services.prometheus.stateDir}" = {
        device = config.utils.dataDir "prometheus2";
        fsType = "none";
        options = [ "bind" ];
      };

      systemd.tmpfiles.rules = [ "d ${lokiDir} 0750 loki loki -" ];
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
