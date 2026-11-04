{
  config,
  lib,
  pkgs,
  microvmLib,
  sshKeys,
  ...
}:
let
  dataset = "rpool/persist";
  inherit (microvmLib) vmParent;
  snapshot = "backup-staging";
  # Relative to /, which the archive is built from.
  snapshotPath = dir: "${lib.removePrefix "/" dir}/.zfs/snapshot/${snapshot}";
  outDir = "/tank/callum/backups";
  outFile = "${outDir}/liz-persist.tar.zst.age";

  recipients = pkgs.writeText "liz-persist-backup-recipients" (lib.concatLines sshKeys);

  # The shell expands globs.
  paths = [
    # nix-secrets decrypts with the SSH host key.
    "etc/ssh"
    "etc/machine-id"
    "passwd"
    "var/lib/nixos"
    "var/lib/systemd/credential.secret"
    "var/lib/tailscale"
    "var/lib/samba"

    "data/qbittorrent"
    "data/radicale"
    "data/gitea"
    "data/leafwiki"
    "data/syncthing"
    "data/home-assistant"
    "data/trilium"

    "data/media/jellyfin/config/config"
    "data/media/jellyfin/config/plugins/configurations"
    "data/media/jellyfin/config/root"
    "data/media/jellyfin/config/data/playlists"
    "data/media/jellyfin/config/data/jellyfin.db*"

    "data/media/sonarr/config.xml"
    "data/media/sonarr/sonarr.db*"
    "data/media/radarr/config.xml"
    "data/media/radarr/radarr.db*"
    "data/media/prowlarr/config.xml"
    "data/media/prowlarr/prowlarr.db*"

    "data/media/slskd/slskd.yml"
    "data/media/slskd/data"
  ];

  vmPaths = {
    gallery = [
      "etc/ssh"
      "var/lib/nixos"
      "var/lib/tailscale"
      "data/gallery-db"
    ];
    thsconline = [
      "etc/ssh"
      "var/lib/nixos"
    ];
    gpu = [
      "etc/ssh"
      "var/lib/nixos"
    ];
  };

  members =
    map (p: "${snapshotPath config.utils.persistDir}/${p}") paths
    ++ lib.concatLists (
      lib.mapAttrsToList (name: map (p: "${snapshotPath (microvmLib.vmDir name)}/${p}")) vmPaths
    );

  # /persist paths keep their old place at the archive root.
  transforms = [
    "s,^${snapshotPath config.utils.persistDir}/,,"
    "s,^\\(vm/[^/]*\\)/\\.zfs/snapshot/${snapshot}/,\\1/,"
  ];

  excludes = [
    # Reinstall HACS with get.hacs.xyz. Its state in .storage is kept.
    "data/home-assistant/custom_components/hacs"
    "data/home-assistant/backups"
    "data/home-assistant/deps"
    "data/home-assistant/tts"
    "data/home-assistant/home-assistant.log*"
    "data/home-assistant/home-assistant_v2.db*"
    "data/qbittorrent/qBittorrent/data/GeoDB"
    "data/qbittorrent/qBittorrent/data/logs"
    "data/media/slskd/data/backups"
    "data/media/slskd/data/browse.cache"
    "data/media/slskd/data/search.db"
    "data/media/slskd/data/shares.local.bak.db"
    "data/syncthing/index-v2"
    "data/trilium/backup"
    "data/trilium/log"
  ];

  backup = pkgs.writeShellApplication {
    name = "liz-persist-backup";
    runtimeInputs = with pkgs; [
      age
      config.boot.zfs.package
      coreutils
      gnutar
      util-linux
      zstd
    ];
    text = ''
      # tank imports outside systemd's mount graph. Never write to the ephemeral root.
      mountpoint -q /tank/callum

      cleanup() {
        zfs destroy ${dataset}@${snapshot} 2>/dev/null || true
        zfs destroy -r ${vmParent}@${snapshot} 2>/dev/null || true
      }
      cleanup
      # One atomic snapshot across /persist and every VM.
      zfs snapshot -r ${dataset}@${snapshot} ${vmParent}@${snapshot}
      tmp=
      trap 'rm -f "$tmp"; cleanup' EXIT

      install -d -o callum -g users -m 0700 ${outDir}
      tmp=$(mktemp ${outFile}.XXXXXX)

      cd /
      # shellcheck disable=SC2086
      tar --create --numeric-owner --acls --xattrs \
        ${lib.concatMapStringsSep " " (t: "--transform=${lib.escapeShellArg t}") transforms} \
        ${lib.concatMapStringsSep " " (e: "--exclude=${lib.escapeShellArg e}") excludes} \
        ${lib.concatStringsSep " " members} \
        | zstd -T0 -10 \
        | age -R ${recipients} > "$tmp"

      chown callum:users "$tmp"
      chmod 0600 "$tmp"
      mv "$tmp" ${outFile}
    '';
  };
in
{
  systemd.services.liz-persist-backup = {
    description = "Encrypted archive of important /persist and VM state into /tank/callum";
    after = [ "zfs-mount.service" ];
    onSuccess = [ "offsite-backup.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe backup;
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  modules.offsiteBackup.file = outFile;

  systemd.timers.liz-persist-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };
}
