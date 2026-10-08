{
  flake.modules.nixos.monitoring =
    { config, lib, ... }:
    let
      datasourceUid =
        name:
        (lib.findFirst (d: d.name == name) (throw "no Grafana datasource named ${name}")
          config.services.grafana.provision.datasources.settings.datasources
        ).uid;
      promUid = datasourceUid "prometheus";
      lokiUid = datasourceUid "loki";

      # Rules that first lived in the UI keep their UIDs, so provisioning took
      # them over in place rather than duplicating them.
      mkRule =
        {
          uid,
          title,
          expr,
          summary,
          severity ? "warning",
          for ? "5m",
          keepFiringFor ? "0s",
          datasourceUid ? promUid,
          lookback ? 600,
          threshold ? {
            type = "gt";
            params = [ 0 ];
          },
          # queries that drop healthy series pass "OK", since empty means fine
          noDataState ? "NoData",
        }:
        {
          inherit
            uid
            title
            for
            noDataState
            ;
          keep_firing_for = keepFiringFor;
          condition = "C";
          data = [
            {
              refId = "A";
              inherit datasourceUid;
              relativeTimeRange = {
                from = lookback;
                to = 0;
              };
              model = {
                refId = "A";
                inherit expr;
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
                conditions = [ { evaluator = threshold; } ];
              };
            }
          ];
          execErrState = "Error";
          labels = { inherit severity; };
          annotations = { inherit summary; };
          notification_settings.receiver = "telegram";
        };

      # smartctl_exporter drops a disk it cannot reach instead of reporting an
      # error, so a dead link shows up as a missing series. Compare against the
      # declared device list to notice the gap.
      expectedDisks = lib.concatLists (
        lib.mapAttrsToList (
          host: hostCfg:
          map (
            device:
            ''label_replace(label_replace(vector(1), "instance", "${host}", "", ""), "device", "${device}", "", "")''
          ) (hostCfg.smartctlDevices or [ ])
        ) config.modules.metrics.hosts
      );

      mkGroup = name: rules: {
        orgId = 1;
        inherit name rules;
        folder = "Alerts";
        interval = "1m";
      };
    in
    {
      services.grafana.provision.alerting.rules.settings = {
        apiVersion = 1;
        # Dropping a rule from `groups` leaves it running: file provisioning only
        # deletes rules listed here. "Target down" was retired, so it needs a
        # tombstone until someone removes it from the live instance by hand.
        deleteRules = [
          {
            orgId = 1;
            uid = "cfoxgrt2f1ji8b";
          }
        ];
        groups = [
          (mkGroup "system" [
            (mkRule {
              uid = "bfoy1tqcgcagwf";
              title = "Reboot";
              severity = "info";
              for = "0s";
              expr = "changes(node_boot_time_seconds[15m])";
              summary = "{{ $labels.instance }} rebooted.";
            })
            (mkRule {
              uid = "bfoy0zaeqm0w0a";
              title = "Failed systemd unit";
              severity = "info";
              expr = ''node_systemd_unit_state{state="failed"}'';
              summary = "systemd unit {{ $labels.name }} failed on {{ $labels.instance }}.";
            })
            (mkRule {
              uid = "cfoy1fcgfpjwga";
              title = "OOM kills";
              for = "0s";
              expr = "increase(node_vmstat_oom_kill[10m])";
              summary = ''{{ $labels.instance }} had {{ printf "%.0f" $values.A.Value }} processes killed for running out of memory in the last 10 minutes.'';
            })
            (mkRule {
              uid = "bfoy1nw46zitcb";
              title = "Sustained high load";
              for = "30m";
              expr = ''node_load5 / on(instance) group_left() count by (instance) (node_cpu_seconds_total{mode="idle"})'';
              threshold = {
                type = "gt";
                params = [ 2 ];
              };
              summary = ''{{ $labels.instance }} system load is consistently higher than normal ({{ printf "%.1f" $values.A.Value }} per core).'';
            })
            (mkRule {
              uid = "ffoxxonpsr4lcd";
              title = "Filesystem nearly full";
              lookback = 86400;
              expr = ''node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay|squashfs",mountpoint=~"/|/persist|/boot"} / node_filesystem_size_bytes'';
              threshold = {
                type = "lt";
                params = [ 0.1 ];
              };
              summary = "{{ $labels.mountpoint }} on {{ $labels.instance }} has only {{ humanizePercentage $values.A.Value }} free.";
            })
            (mkRule {
              uid = "afoy1avtbagaof";
              title = "Container restart loop";
              for = "0s";
              expr = ''changes(container_start_time_seconds{name!=""}[5m])'';
              threshold = {
                type = "gt";
                params = [ 3 ];
              };
              summary = ''Container {{ $labels.name }} on {{ $labels.instance }} restarted {{ printf "%.0f" $values.A.Value }} times in the last 5 minutes.'';
            })
            (mkRule {
              uid = "afoy2895p9o8wc";
              title = "Error log spike";
              datasourceUid = lokiUid;
              expr = ''sum by (host, unit) (rate({job="systemd-journal"} |~ "(?i)\\b(error|fatal|panic|segfault)\\b" [5m]))'';
              threshold = {
                type = "gt";
                params = [ 1 ];
              };
              noDataState = "OK";
              summary = ''{{ $labels.unit }} on {{ $labels.host }} is logging {{ printf "%.2f" $values.A.Value }} errors per second.'';
            })
          ])

          (mkGroup "storage" [
            (mkRule {
              uid = "afoxi4vvr0u80d";
              title = "ZFS pool unhealthy";
              severity = "critical";
              for = "2m";
              expr = "zfs_pool_health";
              threshold = {
                type = "ne";
                params = [ 0 ];
              };
              summary = "ZFS pool {{ $labels.pool }} on {{ $labels.instance }} is {{ $v := $values.A.Value }}{{ if eq $v 1.0 }}DEGRADED{{ else if eq $v 2.0 }}FAULTED{{ else if eq $v 3.0 }}OFFLINE{{ else if eq $v 4.0 }}UNAVAIL{{ else if eq $v 5.0 }}REMOVED{{ else if eq $v 6.0 }}SUSPENDED{{ else }}in state {{ $v }}{{ end }}.";
            })
            (mkRule {
              uid = "cfflrrh4zewowf";
              title = "ZFS pool usage";
              for = "1m";
              lookback = 86400;
              expr = "zfs_pool_allocated_bytes / zfs_pool_size_bytes";
              threshold = {
                type = "gt";
                params = [ 0.8 ];
              };
              summary = "ZFS pool {{ $labels.pool }} on {{ $labels.instance }} is {{ humanizePercentage $values.A.Value }} full.";
            })
            (mkRule {
              uid = "dfoxxttba5l34b";
              title = "SMART health failed";
              severity = "critical";
              for = "1m";
              expr = "smartctl_device_smart_status";
              threshold = {
                type = "lt";
                params = [ 1 ];
              };
              summary = "SMART health is failing on {{ $labels.device }} ({{ $labels.model_name }}) on {{ $labels.instance }}.";
            })
            (mkRule {
              uid = "disk-missing";
              title = "Disk missing from SMART";
              severity = "critical";
              for = "15m";
              noDataState = "OK";
              expr = ''
                (${lib.concatStringsSep "\n or " expectedDisks})
                unless on(instance, device) smartctl_device_smart_status
                and on(instance) up{job="smartctl"} == 1
              '';
              summary = "{{ $labels.device }} on {{ $labels.instance }} stopped answering SMART; check its cable, HBA port and zpool status.";
            })
            (mkRule {
              # replaced "SMART sectors degrading", which fired forever on any non-zero count
              uid = "afoy0sj8sycjkf";
              title = "SMART error counters rising";
              lookback = 3600;
              noDataState = "OK";
              # rise over the window's minimum: delta() extrapolates and inflates the
              # number, and offset finds nothing when the disk has just reappeared
              expr =
                let
                  attrs = ''smartctl_device_attribute{attribute_value_type="raw",attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Reported_Uncorrect|Offline_Uncorrectable|UDMA_CRC_Error_Count"}'';
                  media = "smartctl_device_media_errors";
                in
                ''
                  ${attrs} - min_over_time(${attrs}[1h]) > 0
                  or label_replace(${media} - min_over_time(${media}[1h]) > 0, "attribute_name", "media_errors", "", "")
                '';
              summary = ''{{ $labels.device }} on {{ $labels.instance }}: {{ $labels.attribute_name }} rose by {{ printf "%.0f" $values.A.Value }} in the last hour. UDMA_CRC_Error_Count points at the cable or HBA port, the rest at the disk.'';
            })
            (mkRule {
              uid = "kernel-disk-errors";
              title = "Kernel disk I/O errors";
              severity = "critical";
              for = "0s";
              keepFiringFor = "30m";
              noDataState = "OK";
              datasourceUid = lokiUid;
              # kernel lines carry no unit label; without that filter, Grafana's own
              # log of this query matches it and the rule fires on itself
              expr = ''sum by (host) (count_over_time({job="systemd-journal", unit=""} |~ "I/O error, dev|iuCRC error|zio pool=" [10m]))'';
              summary = ''{{ $labels.host }} logged {{ printf "%.0f" $values.A.Value }} disk I/O errors in 10 minutes.'';
            })
            (mkRule {
              # replaced "SmartCTL NVMe health", whose expression never produced data
              uid = "bfflrwn833kzke";
              title = "NVMe health";
              severity = "critical";
              noDataState = "OK";
              expr = ''
                smartctl_device_critical_warning > 0
                or smartctl_device_percentage_used >= 90
                or smartctl_device_available_spare <= smartctl_device_available_spare_threshold
              '';
              summary = "NVMe {{ $labels.device }} on {{ $labels.instance }} is wearing out or raised a critical warning.";
            })
          ])
        ]
        ++ lib.optional (config.systemd.timers ? thsconline-sync) (
          mkGroup "thsconline" [
            (mkRule {
              uid = "thsconline-stale";
              title = "THSC Online sync stale";
              # no data means the metrics file is missing, which is worth hearing about too
              expr = "time() - max by (instance) (thsconline_sync_last_success_timestamp_seconds)";
              threshold = {
                type = "gt";
                params = [ (36 * 3600) ];
              };
              summary = "The THSC Online mirror on {{ $labels.instance }} last synced successfully {{ humanizeDuration $values.A.Value }} ago; check thsconline-sync.service.";
            })
            (mkRule {
              uid = "thsconline-removal-refused";
              title = "THSC Online sync refused removals";
              for = "0s";
              noDataState = "OK";
              expr = "thsconline_sync_removal_refused";
              summary = "The THSC Online sync on {{ $labels.instance }} stopped rather than delete more than 2% of the mirror. Check with sync.py --dry-run, then rerun with --force if the site really dropped them.";
            })
            (mkRule {
              uid = "thsconline-unavailable-jump";
              title = "THSC Online papers unavailable";
              for = "0s";
              noDataState = "OK";
              expr = "thsconline_sync_unavailable_change";
              threshold = {
                type = "gt";
                params = [ 50 ];
              };
              summary = ''The THSC Online site stopped serving {{ printf "%.0f" $values.A.Value }} more papers in the last sync on {{ $labels.instance }}; its download servers may be broken.'';
            })
          ]
        );
      };
    };
}
