# OnlyBoxes self-hosted code-execution sandbox (https://onlybox.es), used as the
# `SANDBOX_PROVIDER=onlyboxes` backend for LobeHub's built-in cloud sandbox.
#
# Two parts:
#   - Console: auth + worker registry + REST/MCP API (container image). LobeHub
#     calls its REST API and the worker registers over gRPC.
#   - Worker: actually runs the sandboxed code. It shells out to the `docker`
#     CLI to spawn sandbox containers, so it runs as a host systemd service with
#     a `docker` -> podman shim rather than as a container itself.
#
# Bring-up is two-phase: the worker's WORKER_ID / WORKER_SECRET are minted
# interactively in the Console dashboard, then added to the worker env secret.
{ inputs, lib, ... }:
let
  # Reuse the lobehub podman network (defined in ./lobehub.nix) so the LobeHub
  # server container can reach the Console directly by static IP.
  consoleIp = "172.28.0.6";
  runtimeImage = "docker.io/coolfan1024/onlyboxes-runtime:lobehub";
in
{
  flake.modules.nixos.quadlet-onlyboxes =
    { config, pkgs, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
      worker = pkgs.callPackage ../../../packages/onlyboxes-worker-docker { };
      podman = config.virtualisation.podman.package;
      # The worker invokes the `docker` CLI directly; route it to rootful podman.
      dockerShim = pkgs.writeShellScriptBin "docker" ''exec ${podman}/bin/podman "$@"'';
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      modules.containers.onlyboxes = lib.mkDefault true;

      systemd.tmpfiles.rules = [
        "d ${config.utils.dataDir "onlyboxes/db"} 0755 root root -"
      ];

      # CONSOLE_HASH_KEY, CONSOLE_JIT_SIGNING_KEY and the first-run admin
      # credentials (CONSOLE_DASHBOARD_USERNAME / CONSOLE_DASHBOARD_PASSWORD).
      sops.secrets."docker/onlyboxes_env" = {
        owner = "root";
        group = "root";
        mode = "0440";
        restartUnits = [ "onlyboxes-console.service" ];
      };

      # WORKER_ID and WORKER_SECRET, minted in the Console dashboard.
      sops.secrets."docker/onlyboxes_worker_env" = {
        owner = "root";
        group = "root";
        mode = "0440";
        restartUnits = [ "onlyboxes-worker.service" ];
      };

      virtualisation.quadlet.containers.onlyboxes-console = lib.mkIf config.modules.containers.onlyboxes (
        config.utils.mkContainer {
          containerConfig = {
            image = "docker.io/coolfan1024/onlyboxes:latest";
            autoUpdate = "registry";
            environmentFiles = [ config.sops.secrets."docker/onlyboxes_env".path ];
            environments = {
              CONSOLE_HTTP_ADDR = ":8089";
              CONSOLE_GRPC_ADDR = ":50051";
              CONSOLE_DB_PATH = "/app/db/onlyboxes-console.db";
              CONSOLE_ENABLE_REGISTRATION = "false";
            };
            networks = [ networks.lobehub.ref ];
            ip = consoleIp;
            # 8089 (HTTP/REST) for the gateway; 50051 (gRPC) for the host worker.
            publishPorts = [
              "8089:8089"
              "127.0.0.1:50051:50051"
            ];
            volumes = [
              "${config.utils.dataDir "onlyboxes/db"}:/app/db"
            ];
          };
        }
      );

      systemd.services.onlyboxes-worker = lib.mkIf config.modules.containers.onlyboxes {
        description = "OnlyBoxes worker (docker runtime)";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "onlyboxes-console.service"
        ];
        wants = [ "network-online.target" ];
        path = [
          podman
          dockerShim
          pkgs.iptables
          pkgs.iproute2
          pkgs.util-linux
        ];
        environment = {
          WORKER_CONSOLE_INSECURE = "true";
          WORKER_CONSOLE_GRPC_TARGET = "127.0.0.1:50051";
          WORKER_NODE_NAME = "salt";
          # LobeHub-specific terminal runtime image and raised per-session limits.
          WORKER_TERMINAL_EXEC_DOCKER_IMAGE = runtimeImage;
          WORKER_TERMINAL_EXEC_MEMORY_MIB = "2048";
          WORKER_TERMINAL_EXEC_CPUS = "2";
          WORKER_TERMINAL_EXEC_MAX_PROCESSES = "1024";
        };
        serviceConfig = {
          EnvironmentFile = config.sops.secrets."docker/onlyboxes_worker_env".path;
          # Pre-pull the (large) runtime image so the first session isn't blocked
          # on the download; non-fatal so the worker still starts when offline.
          ExecStartPre = "-${dockerShim}/bin/docker pull ${runtimeImage}";
          ExecStart = lib.getExe worker;
          Restart = "always";
          RestartSec = "10";
          Delegate = "yes";
        };
      };
    };

  flake.modules.nixos.gateway =
    { config, ... }:
    {
      modules.gateway.services.onlyboxes = {
        name = "OnlyBoxes";
        domainName = "onlyboxes";
        addr = "${config.modules.hostAddrs.salt}:8089";
        iconUrl = "https://cdn.jsdelivr.net/gh/Coooolfan/onlyboxes@0.7.1/website/public/favicon.png";
        category = "Productivity";
      };
    };
}
