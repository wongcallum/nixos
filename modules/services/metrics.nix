{
  flake.modules.nixos.metrics =
    { config, lib, ... }:
    let
      hostname = config.networking.hostName;
      exporters = (config.modules.metrics.hosts.${hostname} or { }).exporters or [ ];
      has = e: builtins.elem e exporters;
    in
    {
      services.prometheus.exporters = {
        node = lib.mkIf (has "node") {
          enable = true;
          enabledCollectors = [
            "logind"
            "processes"
            "systemd"
            "tcpstat"
          ];
          port = 9002;
        };

        smartctl = lib.mkIf (has "smartctl") {
          enable = true;
          port = 9003;
        };

        zfs = lib.mkIf (has "zfs") {
          enable = true;
          port = 9004;
        };
      };
    };
}
