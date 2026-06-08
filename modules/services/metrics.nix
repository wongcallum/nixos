{ lib, ... }:
{
  # Prometheus exporters, imported by every monitored host. The central
  # Prometheus server + Grafana live in the separate, liz-only `monitoring`
  # feature, which scrapes these over the tailnet.
  flake.modules.nixos.metrics =
    { config, ... }:
    {
      services.prometheus.exporters = {
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

        # Only runs where ZFS is actually in use; mkDefault lets a host override.
        zfs = {
          enable = lib.mkDefault config.boot.zfs.enabled;
          port = 9004;
        };
      };
    };
}
