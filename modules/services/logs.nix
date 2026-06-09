{ lib, ... }:
{
  flake.modules.nixos.logs =
    { config, ... }:
    let
      server = config.modules.monitoring.host;
      hostname = config.networking.hostName;
      lokiAddr = if hostname == server then "127.0.0.1" else config.modules.hostAddrs.${server};
    in
    {
      environment.etc."alloy/config.alloy".text = ''
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

        loki.write "default" {
          endpoint {
            url = "http://${lokiAddr}:3100/loki/api/v1/push"
          }
        }
      '';

      services.alloy.enable = true;
    };

  # nothing actually important here but persist so reboot/rebuild doesn't push the journal again
  flake.modules.nixos.persistence =
    { config, ... }:
    {
      environment.persistence.${config.modules.persistence.persistDir}.directories =
        lib.mkIf config.services.alloy.enable
          [ "/var/lib/private/alloy" ];
    };
}
