{ lib, ... }:
{
  flake.modules.nixos.logs =
    { config, ... }:
    let
      server = config.modules.monitoring.host;
      hostname = config.networking.hostName;
    in
    {
      options.modules.logs.lokiAddr = lib.mkOption {
        type = lib.types.str;
        default = if hostname == server then "127.0.0.1" else config.modules.hostAddrs.${server};
        description = "Address of the Loki server, which a VM reaches over its own link.";
      };

      options.modules.logs.journalDirs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Other machines' journal directories on this host's disk, such as VMs' persisted /var/log/journal.";
      };

      config.environment.etc."alloy/config.alloy".text = ''
        discovery.relabel "journal" {
          targets = []
          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }
          rule {
            source_labels = ["__journal__hostname"]
            target_label  = "host"
          }
        }

        loki.source.journal "journal" {
          max_age       = "12h"
          relabel_rules = discovery.relabel.journal.rules
          forward_to    = [loki.write.default.receiver]
          labels        = { job = "systemd-journal", host = "${hostname}" }
        }

        ${lib.concatImapStrings (i: dir: ''
          loki.source.journal "dir_${toString i}" {
            path          = "${dir}"
            max_age       = "12h"
            relabel_rules = discovery.relabel.journal.rules
            forward_to    = [loki.write.default.receiver]
            labels        = { job = "systemd-journal" }
          }
        '') config.modules.logs.journalDirs}
        loki.write "default" {
          endpoint {
            url = "http://${config.modules.logs.lokiAddr}:${toString config.modules.monitoring.lokiPort}/loki/api/v1/push"
          }
        }
      '';

      config.services.alloy.enable = true;
    };

  # Persisted so a reboot doesn't push the journal again.
  flake.modules.nixos.persistence =
    { config, ... }:
    {
      environment.persistence.${config.modules.persistence.persistDir}.directories =
        lib.mkIf config.services.alloy.enable
          [ "/var/lib/private/alloy" ];
    };
}
