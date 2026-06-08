{
  flake.modules.nixos.monitoring =
    { config, lib, ... }:
    let
      exporterPorts = {
        node = 9002;
        zfs = 9004;
        smartctl = 9003;
      };
      # Which exporters each monitored host runs. Explicit (not flake-derived);
      # keep in sync with what the metrics/monitoring modules enable per host.
      hostExporters = {
        liz = [
          "node"
          "zfs"
          "smartctl"
        ];
        staging = [
          "node"
          "zfs"
        ];
      };
      # Self over loopback (no tailnet dependency to scrape ourselves); remotes
      # via their tailscale IP from the global modules.hostAddrs map.
      addrOf =
        host: if host == config.networking.hostName then "127.0.0.1" else config.modules.hostAddrs.${host};
      mkJob = exporter: {
        job_name = exporter;
        static_configs = lib.mapAttrsToList (host: _: {
          targets = [ "${addrOf host}:${toString exporterPorts.${exporter}}" ];
          labels.instance = host;
        }) (lib.filterAttrs (_: exporters: builtins.elem exporter exporters) hostExporters);
      };
    in
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
        # node + zfs exporters come from the `metrics` feature; smartctl stays
        # here (liz-only for now) alongside the server.
        exporters.smartctl = {
          enable = true;
          port = 9003;
        };
        # One job per exporter type; each host contributes a static_config with
        # its own `instance` label. Targets resolve via modules.hostAddrs.
        scrapeConfigs = map mkJob (builtins.attrNames exporterPorts);
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
