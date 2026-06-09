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

      services.cadvisor = lib.mkIf (has "cadvisor") {
        enable = true;
        listenAddress = "0.0.0.0";
        port = 9005;
        extraOptions = [
          "--docker_only=false" # also report podman/systemd cgroups
          "--disable_metrics=disk" # this kills CPU on zfs hosts per container
        ];
      };

      # FIXME: https://github.com/NixOS/nixpkgs/pull/520137
      nixpkgs.overlays = lib.mkIf (has "cadvisor") [
        (_: prev: {
          cadvisor = prev.cadvisor.overrideAttrs (_: {
            version = "0.57.0";
            src = prev.fetchFromGitHub {
              owner = "google";
              repo = "cadvisor";
              rev = "v0.57.0";
              hash = "sha256-9HeiSO6yedDpv6YUAdZU7CqfGkun4ugZs4RbSZ51MPU=";
            };
            vendorHash = "sha256-zPn7CqSw+SW0Air5dEs+/wNwNAJjd5XX7wC3hrOHJQU=";
          });
        })
      ];
    };
}
