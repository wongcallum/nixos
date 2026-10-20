let
  ispHost = "ISP gateway";

  # PromQL shared by the Grafana dashboard and the Home Assistant sensors
  queries = cfg: {
    router = ''host="${cfg.router}"'';
    isp = ''host="${ispHost}"'';
    internet = ''host!="${cfg.router}",host!="${ispHost}"'';

    loss =
      selector: window:
      "clamp_min(1 - sum by (host) (rate(smokeping_response_duration_seconds_count{${selector}}[${window}])) / sum by (host) (rate(smokeping_requests_total{${selector}}[${window}])), 0)";
    rtt =
      q: selector: window:
      "histogram_quantile(${toString q}, sum by (host, le) (rate(smokeping_response_duration_seconds_bucket{${selector}}[${window}])))";
  };
in
{
  flake.modules.nixos.monitoring =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.uplink;
      inherit (queries cfg)
        router
        isp
        internet
        loss
        rtt
        ;
      exporter = config.services.prometheus.exporters.smokeping;

      datasource = {
        type = "prometheus";
        uid = config.modules.monitoring.datasourceUids.prometheus;
      };

      # found at runtime by uplink-isp-gateway, so the ISP stays out of this public repo
      ispConfig = "/run/uplink/isp-gateway.yml";
      lossThresholds = {
        mode = "absolute";
        steps = [
          {
            color = "green";
            value = null;
          }
          {
            color = "orange";
            value = 0.01;
          }
          {
            color = "red";
            value = 0.05;
          }
        ];
      };

      target = expr: legendFormat: { inherit datasource expr legendFormat; };

      panel =
        {
          title,
          description ? "",
          type ? "timeseries",
          x,
          y,
          w ? 12,
          h ? 8,
          unit,
          targets,
          extra ? { },
        }:
        lib.recursiveUpdate {
          inherit
            title
            description
            type
            datasource
            ;
          gridPos = {
            inherit
              x
              y
              w
              h
              ;
          };
          fieldConfig = {
            defaults = {
              inherit unit;
              min = 0;
            };
            overrides = [
              {
                matcher = {
                  id = "byName";
                  options = cfg.router;
                };
                properties = [
                  {
                    id = "displayName";
                    value = "router";
                  }
                ];
              }
            ];
          };
          targets = lib.imap0 (i: t: t // { refId = builtins.elemAt [ "A" "B" "C" "D" "E" ] i; }) targets;
        } extra;

      dashboard = {
        uid = "uplink";
        title = "Uplink";
        description = "Packet loss and latency from ${config.networking.hostName} to the router, the ISP gateway and the internet";
        schemaVersion = 39;
        refresh = "1m";
        time = {
          from = "now-24h";
          to = "now";
        };
        panels = [
          (panel {
            title = "Availability";
            description = "Share of pings answered over the dashboard's time range, by the best-reached internet host";
            type = "stat";
            x = 0;
            y = 0;
            w = 5;
            h = 4;
            unit = "percentunit";
            # the best-reached target, so one host dropping ICMP doesn't count
            targets = [ (target "1 - min(${loss internet "$__range"})" "availability") ];
            extra.options.reduceOptions.calcs = [ "lastNotNull" ];
            extra.fieldConfig.defaults = {
              decimals = 3;
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "red";
                    value = null;
                  }
                  {
                    color = "orange";
                    value = 0.99;
                  }
                  {
                    color = "green";
                    value = 0.999;
                  }
                ];
              };
            };
          })
          (panel {
            title = "Internet loss";
            description = "Pings lost over the last 5 minutes, by the best-reached internet host";
            type = "stat";
            x = 5;
            y = 0;
            w = 5;
            h = 4;
            unit = "percentunit";
            targets = [ (target "min(${loss internet "5m"})" "internet") ];
            extra.options.reduceOptions.calcs = [ "lastNotNull" ];
            extra.fieldConfig.defaults.thresholds = lossThresholds;
          })
          (panel {
            # loss here as well as to the internet is the line to the ISP, not the wider internet
            title = "ISP loss";
            description = "Pings lost to the ISP gateway over the last 5 minutes";
            type = "stat";
            x = 10;
            y = 0;
            w = 5;
            h = 4;
            unit = "percentunit";
            targets = [ (target (loss isp "5m") ispHost) ];
            extra.options.reduceOptions.calcs = [ "lastNotNull" ];
            extra.fieldConfig.defaults.thresholds = lossThresholds;
          })
          (panel {
            title = "Internet ping";
            description = "Median round trip over the last 5 minutes, by the fastest internet host";
            type = "stat";
            x = 15;
            y = 0;
            w = 5;
            h = 4;
            unit = "s";
            targets = [ (target "min(${rtt 0.5 internet "5m"})" "internet") ];
            extra.options.reduceOptions.calcs = [ "lastNotNull" ];
          })
          (panel {
            title = "Router ping";
            description = "Median round trip to the LAN router over the last 5 minutes";
            type = "stat";
            x = 20;
            y = 0;
            w = 4;
            h = 4;
            unit = "s";
            targets = [ (target (rtt 0.5 router "5m") "router") ];
            extra.options.reduceOptions.calcs = [ "lastNotNull" ];
          })
          (panel {
            title = "Packet loss";
            x = 0;
            y = 4;
            w = 24;
            unit = "percentunit";
            targets = [ (target (loss ''host=~".+"'' "$__rate_interval") "{{host}}") ];
            extra.fieldConfig.defaults = {
              # stays at 0-5% on a quiet day so blips look small, grows to 100% for an outage
              softMax = 0.05;
              custom = {
                drawStyle = "bars";
                fillOpacity = 60;
              };
            };
          })
          (panel {
            title = "Median RTT";
            x = 0;
            y = 12;
            unit = "s";
            targets = [ (target (rtt 0.5 ''host=~".+"'' "$__rate_interval") "{{host}}") ];
          })
          (panel {
            title = "95th percentile RTT (jitter)";
            x = 12;
            y = 12;
            unit = "s";
            targets = [ (target (rtt 0.95 ''host=~".+"'' "$__rate_interval") "{{host}}") ];
          })
          (panel {
            title = "Internet RTT distribution";
            type = "heatmap";
            x = 0;
            y = 20;
            w = 24;
            h = 10;
            # cells count replies per second; the y axis carries the latency unit
            unit = "pps";
            targets = [
              (
                target "sum by (le) (rate(smokeping_response_duration_seconds_bucket{${internet}}[$__rate_interval]))" "{{le}}"
                // {
                  format = "heatmap";
                }
              )
            ];
            extra = {
              options = {
                calculate = false;
                yAxis.unit = "s";
                color.scheme = "Spectral";
              };
            };
          })
        ];
      };
    in
    {
      options.modules.uplink = {
        router = lib.mkOption {
          type = lib.types.str;
          default = "192.168.0.1";
          description = ''
            LAN router to ping. Loss to the router as well as the internet
            points at the LAN or the router itself rather than the ISP.
          '';
        };

        targets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          # IPs rather than names, so a DNS failure doesn't look like packet loss
          default = [
            "1.1.1.1"
            "8.8.8.8"
            "9.9.9.9"
          ];
          description = ''
            Internet hosts to ping. The headline panels take the best of them, so one host
            rate-limiting ICMP doesn't read as a flaky uplink.
          '';
        };
      };

      config = {
        services.prometheus = {
          exporters.smokeping = {
            enable = true;
            listenAddress = "127.0.0.1";
            hosts = [ cfg.router ] ++ cfg.targets;
            # a missing file is ignored, so the prober runs without the gateway until it is found
            extraFlags = [ "--config.file=${ispConfig}" ];
            # finer than the default doubling buckets, so a 20ms rise is visible
            buckets = lib.concatStringsSep "," [
              "0.0002"
              "0.0005"
              "0.001"
              "0.002"
              "0.004"
              "0.006"
              "0.008"
              "0.01"
              "0.0125"
              "0.015"
              "0.0175"
              "0.02"
              "0.025"
              "0.03"
              "0.04"
              "0.05"
              "0.075"
              "0.1"
              "0.15"
              "0.2"
              "0.3"
              "0.5"
              "1"
              "2"
            ];
          };

          scrapeConfigs = [
            {
              job_name = "smokeping";
              scrape_interval = "15s";
              metric_relabel_configs = [
                {
                  source_labels = [ "role" ];
                  regex = "isp";
                  target_label = "host";
                  replacement = ispHost;
                }
                {
                  regex = "role";
                  action = "labeldrop";
                }
              ];
              static_configs = [
                {
                  targets = [ "${exporter.listenAddress}:${toString exporter.port}" ];
                  labels.instance = config.networking.hostName;
                }
              ];
            }
          ];
        };

        systemd = {
          # The hop after the router, traced with ICMP since it ignores tracepath's
          # UDP. Rerun hourly so the probe follows the ISP renumbering its gateway.
          services.uplink-isp-gateway = {
            description = "Find the ISP gateway for the smokeping prober";
            path = [
              pkgs.traceroute
              pkgs.gawk
            ];
            serviceConfig = {
              Type = "oneshot";
              RuntimeDirectory = "uplink";
              RuntimeDirectoryPreserve = true;
            };
            script = ''
              hop=$(traceroute -I -n -m 2 -q 3 -w 2 ${lib.head cfg.targets} \
                | awk '$1 == 2 { for (i = 2; i <= NF; i++) if ($i ~ /^[0-9]+(\.[0-9]+){3}$/) { print $i; exit } }')
              if [ -z "$hop" ]; then
                echo "no reply from the hop after the router; keeping the previous ISP gateway" >&2
                exit 0
              fi

              new=$(printf 'targets:\n- hosts: [%s]\n  labels:\n    role: isp\n' "$hop")
              if [ "$new" != "$(cat ${ispConfig} 2>/dev/null)" ]; then
                echo "ISP gateway is $hop"
                printf '%s\n' "$new" > ${ispConfig}.tmp
                mv ${ispConfig}.tmp ${ispConfig}
                # workaround: smokeping-reload-panic
                # 0.11.0 panics re-registering its metrics on SIGHUP, so restart instead
                systemctl try-restart prometheus-smokeping-exporter.service
              fi
            '';
          };

          timers.uplink-isp-gateway = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "1min";
              OnUnitActiveSec = "1h";
            };
          };
        };

        services.grafana.provision.dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "uplink";
              folder = "Network";
              options.path = pkgs.writeTextDir "uplink.json" (builtins.toJSON dashboard);
            }
          ];
        };
      };
    };

  # The headline numbers as Home Assistant sensors, queried straight from
  # Prometheus over the host network
  flake.modules.nixos.quadlet-automation =
    { config, lib, ... }:
    let
      inherit (queries config.modules.uplink)
        router
        isp
        internet
        loss
        rtt
        ;
      prometheus = config.services.prometheus;

      sensor =
        {
          id,
          name,
          query,
          scale,
          unit,
          extra ? { },
        }:
        {
          resource = "http://${prometheus.listenAddress}:${toString prometheus.port}/api/v1/query";
          params = { inherit query; };
          scan_interval = 60;
          sensor = [
            (
              {
                inherit name;
                unique_id = "uplink_${id}";
                unit_of_measurement = unit;
                state_class = "measurement";
                # an empty result, like the ISP gateway before it is found, is unavailable rather than 0
                availability = "{{ value_json is not none and value_json.data.result | count > 0 }}";
                value_template = "{{ (value_json.data.result[0].value[1] | float * ${toString scale}) | round(3) }}";
              }
              // extra
            )
          ];
        };
      percent = {
        scale = 100;
        unit = "%";
      };
      ms = {
        scale = 1000;
        unit = "ms";
        extra.device_class = "duration";
      };
    in
    {
      modules.homeassistant.packages.uplink = lib.mkIf prometheus.exporters.smokeping.enable {
        rest = [
          (sensor (
            {
              id = "availability";
              name = "Uplink availability";
              # the dashboard's default range
              query = "1 - min(${loss internet "24h"})";
            }
            // percent
          ))
          (sensor (
            {
              id = "internet_loss";
              name = "Uplink internet loss";
              query = "min(${loss internet "5m"})";
            }
            // percent
          ))
          (sensor (
            {
              id = "isp_loss";
              name = "Uplink ISP loss";
              query = loss isp "5m";
            }
            // percent
          ))
          (sensor (
            {
              id = "internet_ping";
              name = "Uplink internet ping";
              query = "min(${rtt 0.5 internet "5m"})";
            }
            // ms
          ))
          (sensor (
            {
              id = "router_ping";
              name = "Uplink router ping";
              query = rtt 0.5 router "5m";
            }
            // ms
          ))
        ];
      };
    };
}
