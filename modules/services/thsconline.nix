{
  flake.modules.nixos.thsconline =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      root = "/tank/thsconline";
      metricsDir = config.utils.dataDir "thsconline";

      sync = pkgs.writeShellApplication {
        name = "thsconline-sync";
        runtimeInputs = with pkgs; [
          coreutils
          gnused
          jq
          python3
        ];
        text = ''
          # Daily: fetch new entries. Sundays: also retry the ones the site
          # couldn't serve. The 1st of the month: re-download everything.
          # Pass a mode to override.
          mode=''${1:-}
          if [ -z "$mode" ]; then
            if [ "$(date +%-d)" = 1 ]; then
              mode=monthly
            elif [ "$(date +%u)" = 7 ]; then
              mode=weekly
            else
              mode=daily
            fi
          fi
          case $mode in
            daily) flags=() ;;
            weekly) flags=(--retry-unavailable) ;;
            monthly) flags=(--recheck) ;;
            *)
              echo "unknown mode: $mode (expected daily, weekly or monthly)" >&2
              exit 2
              ;;
          esac

          cd ${root}/_sync
          started=$(date +%s)
          unavailable_before=$(jq '.unavailable | length' state.json)

          catalogue=0
          sync=0
          python3 catalogue.py || catalogue=$?
          if [ "$catalogue" = 0 ]; then
            python3 sync.py "''${flags[@]}" || sync=$?
          fi

          finished=$(date +%s)
          success=0
          if [ "$catalogue" = 0 ] && [ "$sync" = 0 ]; then
            success=1
          fi

          # The file holds one success timestamp per mode, so carry the other
          # modes' over from the previous run.
          prom=${metricsDir}/thsconline.prom
          declare -A last=()
          if [ -f "$prom" ]; then
            while read -r m t; do
              last[$m]=$t
            done < <(sed -n 's/^thsconline_sync_last_success_timestamp_seconds{mode="\([a-z]*\)"} \([0-9]*\)$/\1 \2/p' "$prom")
          fi
          if [ "$success" = 1 ]; then
            last[$mode]=$finished
          fi

          gauge() {
            printf '# HELP %s %s\n# TYPE %s gauge\n%s%s %s\n' "$1" "$2" "$1" "$1" "$3" "$4"
          }
          {
            printf '# HELP thsconline_sync_last_success_timestamp_seconds When each sync mode last succeeded.\n'
            printf '# TYPE thsconline_sync_last_success_timestamp_seconds gauge\n'
            for m in "''${!last[@]}"; do
              printf 'thsconline_sync_last_success_timestamp_seconds{mode="%s"} %s\n' "$m" "''${last[$m]}"
            done
            gauge thsconline_sync_last_run_timestamp_seconds "When the last run finished." "{mode=\"$mode\"}" "$finished"
            gauge thsconline_sync_last_run_success "Whether the last run succeeded." "" "$success"
            gauge thsconline_sync_last_run_duration_seconds "How long the last run took." "" "$((finished - started))"
            gauge thsconline_sync_catalogue_exit_code "Exit status of catalogue.py in the last run." "" "$catalogue"
            gauge thsconline_sync_exit_code "Exit status of sync.py in the last run (0 if it didn't run)." "" "$sync"
            gauge thsconline_sync_removal_refused "Whether the last run stopped at the removal limit and needs --force." "" "$((sync == 3))"
            gauge thsconline_sync_mirror_files "Files in the mirror." "" "$(jq '.files | length' state.json)"
            gauge thsconline_sync_unavailable_entries "Catalogue entries the site couldn't serve." "" "$(jq '.unavailable | length' state.json)"
            gauge thsconline_sync_unavailable_change "Change in unavailable entries during the last run." "" \
              "$(($(jq '.unavailable | length' state.json) - unavailable_before))"
          } >"$prom.tmp"
          mv "$prom.tmp" "$prom"

          if [ "$catalogue" != 0 ]; then
            exit "$catalogue"
          fi
          exit "$sync"
        '';
      };
    in
    {
      users.users.thsconline = {
        isSystemUser = true;
        group = "thsconline";
      };
      users.groups.thsconline = { };

      systemd = {
        tmpfiles.rules = [ "d ${metricsDir} 0755 thsconline thsconline -" ];

        services.thsconline-sync = {
          description = "Sync the THSC Online mirror";
          wants = [ "network-online.target" ];
          after = [
            "network-online.target"
            "zfs-mount.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            User = "thsconline";
            Group = "thsconline";
            ExecStart = lib.getExe sync;
            # a monthly recheck downloads the whole mirror again
            TimeoutStartSec = "12h";
            Nice = 10;
            IOSchedulingClass = "idle";
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            NoNewPrivileges = true;
            ReadWritePaths = [
              root
              metricsDir
            ];
          };
        };

        timers.thsconline-sync = {
          wantedBy = [ "timers.target" ];
          timerConfig.OnCalendar = "*-*-* 03:00:00 Australia/Sydney";
        };
      };

      modules.metrics.textfileDirs = [ metricsDir ];
    };
}
