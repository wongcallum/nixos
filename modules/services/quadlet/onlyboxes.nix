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
# The worker's WORKER_ID / WORKER_SECRET are provisioned automatically at deploy
# time by onlyboxes-worker-enroll, which logs into the Console with the dashboard
# credentials and caches the generated credential under the data dir.
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

      # Auto-provisioned worker credential, cached here and reused across deploys.
      workerEnvFile = "${config.utils.dataDir "onlyboxes"}/worker.env";

      # Log into the Console with the dashboard credentials and provision a worker
      # via the REST API, so enrollment needs no manual dashboard step. Idempotent:
      # reuse the cached credential while its worker still exists in the Console.
      enrollScript = pkgs.writeShellScript "onlyboxes-worker-enroll" ''
        set -euo pipefail

        api="http://127.0.0.1:8089"
        envfile="${workerEnvFile}"
        jar="$(mktemp)"
        trap 'rm -f "$jar"' EXIT

        for _ in $(seq 1 60); do
          if curl -fsS -o /dev/null "$api/"; then break; fi
          sleep 2
        done

        curl -fsS -c "$jar" -H 'Content-Type: application/json' \
          --data "$(jq -n --arg u "$CONSOLE_DASHBOARD_USERNAME" --arg p "$CONSOLE_DASHBOARD_PASSWORD" \
            '{username: $u, password: $p}')" \
          "$api/api/v1/console/login" >/dev/null

        if [ -f "$envfile" ]; then
          # shellcheck source=/dev/null
          . "$envfile"
          if [ -n "''${WORKER_ID:-}" ] \
            && curl -fsS -b "$jar" "$api/api/v1/workers?status=all&page_size=100" \
              | jq -e --arg id "$WORKER_ID" '.items[]? | select(.node_id == $id)' >/dev/null; then
            echo "onlyboxes worker $WORKER_ID already registered"
            exit 0
          fi
        fi

        resp="$(curl -fsS -b "$jar" -H 'Content-Type: application/json' \
          --data '{"type": "normal"}' "$api/api/v1/workers")"
        wid="$(printf '%s' "$resp" | jq -r '.node_id')"
        wsecret="$(printf '%s' "$resp" | jq -r '.worker_secret')"
        if [ -z "$wid" ] || [ "$wid" = null ] || [ -z "$wsecret" ] || [ "$wsecret" = null ]; then
          echo "failed to provision onlyboxes worker: $resp" >&2
          exit 1
        fi
        umask 077
        printf 'WORKER_ID=%s\nWORKER_SECRET=%s\n' "$wid" "$wsecret" > "$envfile"
        echo "enrolled onlyboxes worker $wid"
      '';
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      modules.containers.onlyboxes = lib.mkDefault true;

      # CONSOLE_HASH_KEY, CONSOLE_JIT_SIGNING_KEY and the first-run admin
      # credentials (CONSOLE_DASHBOARD_USERNAME / CONSOLE_DASHBOARD_PASSWORD).
      sops.secrets."docker/onlyboxes_env" = {
        owner = "root";
        group = "root";
        mode = "0440";
        restartUnits = [
          "onlyboxes-console.service"
          "onlyboxes-worker-enroll.service"
        ];
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

      systemd = {
        tmpfiles.rules = [
          "d ${config.utils.dataDir "onlyboxes/db"} 0755 root root -"
        ];

        services = {
          # Pull the ~1GiB runtime image once, out of the worker's start path. As a
          # oneshot it gets its own long timeout (the pull blew past the worker's
          # default 90s TimeoutStartSec and crash-looped without ever caching).
          onlyboxes-runtime-pull = lib.mkIf config.modules.containers.onlyboxes {
            description = "Pull OnlyBoxes LobeHub runtime image";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            path = [ podman ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = "3600";
              ExecStart = "${dockerShim}/bin/docker pull ${runtimeImage}";
            };
          };

          # Provision (or reuse) the worker credential via the Console REST API.
          onlyboxes-worker-enroll = lib.mkIf config.modules.containers.onlyboxes {
            description = "Enroll OnlyBoxes worker with the Console";
            wantedBy = [ "multi-user.target" ];
            after = [
              "network-online.target"
              "onlyboxes-console.service"
            ];
            wants = [ "network-online.target" ];
            path = [
              pkgs.curl
              pkgs.jq
              pkgs.coreutils
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              # CONSOLE_DASHBOARD_USERNAME / CONSOLE_DASHBOARD_PASSWORD.
              EnvironmentFile = config.sops.secrets."docker/onlyboxes_env".path;
              ExecStart = enrollScript;
            };
          };

          onlyboxes-worker = lib.mkIf config.modules.containers.onlyboxes {
            description = "OnlyBoxes worker (docker runtime)";
            wantedBy = [ "multi-user.target" ];
            after = [
              "network-online.target"
              "onlyboxes-console.service"
              "onlyboxes-runtime-pull.service"
              "onlyboxes-worker-enroll.service"
            ];
            wants = [
              "network-online.target"
              "onlyboxes-runtime-pull.service"
              "onlyboxes-worker-enroll.service"
            ];
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
              EnvironmentFile = workerEnvFile;
              ExecStart = lib.getExe worker;
              Restart = "always";
              RestartSec = "10";
              Delegate = "yes";
            };
          };
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
