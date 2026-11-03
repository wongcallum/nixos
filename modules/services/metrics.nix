{
  flake.modules.nixos.metrics =
    { config, lib, ... }:
    let
      hostname = config.networking.hostName;
      hostCfg = config.modules.metrics.hosts.${hostname} or { };
      exporters = hostCfg.exporters or [ ];
      has = e: builtins.elem e exporters;
      inherit (config.modules.metrics) ports;
    in
    {
      options.modules.metrics.textfileDirs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Directories whose `*.prom` files the node exporter publishes. Each
          writer owns its own directory, so it can replace its file atomically.
        '';
      };

      config = {
        services.prometheus.exporters = {
          node = lib.mkIf (has "node") {
            enable = true;
            extraFlags = [
              "--collector.systemd.enable-restarts-metrics"
            ]
            ++ map (d: "--collector.textfile.directory=${d}") config.modules.metrics.textfileDirs;
            enabledCollectors = [
              "logind"
              "processes"
              "systemd"
              "tcpstat"
            ];
            port = ports.node;
            openFirewall = hostCfg.address or null != null;
          };

          smartctl = lib.mkIf (has "smartctl") {
            enable = true;
            port = ports.smartctl;
            devices = map (d: "/dev/disk/by-id/${d}") (hostCfg.smartctlDevices or [ ]);
          };

          zfs = lib.mkIf (has "zfs") {
            enable = true;
            port = ports.zfs;
          };
        };

        services.cadvisor = lib.mkIf (has "cadvisor") {
          enable = true;
          listenAddress = "0.0.0.0";
          port = ports.cadvisor;
          extraOptions = [
            "--docker_only=false"

            # On ZFS each pass execs `zfs`. At the default 1s it used about 11% of a core.
            "--housekeeping_interval=30s"

            # This replaces the default set.
            "--disable_metrics=disk,advtcp,cpu_topology,cpuset,hugetlb,memory_numa,process,referenced_memory,resctrl,sched,tcp,udp"
          ];
        };

        # workaround: cadvisor-overlay
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
    };
}
