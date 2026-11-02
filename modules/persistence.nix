{ inputs, lib, ... }:
{
  flake.modules.nixos.persistence =
    { config, pkgs, ... }:
    let
      inherit (config.modules.persistence) persistDir;
      credentialSecret = "/var/lib/systemd/credential.secret";
    in
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];

      options.modules.persistence = {
        persistDir = lib.mkOption {
          type = lib.types.str;
          default = "/persist";
        };
        cacheDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/cache";
          description = ''
            Root for caches that are expensive to rebuild: kept out of persistDir
            and its backups. The default is wiped at boot on impermanent hosts;
            point it at a dedicated dataset to keep caches across reboots.
          '';
        };
      };

      config = {
        fileSystems.${persistDir}.neededForBoot = true;

        # ensure that StateDirectory is not too permissive for DynamicUser services
        systemd.tmpfiles.rules = [ "d /var/lib/private 0700 root root -" ];

        environment.persistence.${persistDir} = {
          enable = true;
          hideMounts = true;
          directories = [
            "/var/lib/nixos"
            "/var/log"
          ];
          files =
            # a declared machine-id (microvm.nix sets one) is already stable
            lib.optional (!(config.environment.etc ? "machine-id")) "/etc/machine-id" ++ [
              # host key for systemd-creds; losing it strands every credential
              # encrypted with it, such as libvirt's secrets-encryption-key
              credentialSecret
            ];
        };

        # Impermanence symlinks a file that is missing from persistent storage,
        # and systemd replaces that symlink when it writes the key, so the key
        # would never persist. Seed it first, adopting a live key if one exists.
        system.activationScripts = {
          credential-secret = {
            # systemd-creds binds the key to the machine-id, which a declared
            # one only provides once /etc is set up
            deps = [
              "createPersistentStorageDirs"
              "etc"
            ];
            text = ''
              persisted=${persistDir}${credentialSecret}
              live=${credentialSecret}
              if [ ! -e "$persisted" ]; then
                mkdir -p "$(dirname "$persisted")"
                if [ -s "$live" ] && [ ! -L "$live" ] && ! ${pkgs.util-linux}/bin/findmnt "$live" >/dev/null; then
                  mv "$live" "$persisted"
                else
                  rm -f "$live"
                  # On a fresh root a persisted machine-id is only bind-mounted
                  # by persist-files, which runs after this, so lend setup a
                  # copy in a private mount namespace.
                  machineId=/etc/machine-id
                  [ -s "$machineId" ] || machineId=${persistDir}/etc/machine-id
                  ${pkgs.util-linux}/bin/unshare --mount ${pkgs.runtimeShell} -c '
                    if [ ! -s /etc/machine-id ]; then
                      ${pkgs.util-linux}/bin/mount -t tmpfs none /etc
                      cp "$1" /etc/machine-id
                    fi
                    SYSTEMD_CREDENTIAL_SECRET="$2" "$3" setup
                  ' _ "$machineId" "$persisted" ${config.systemd.package}/bin/systemd-creds
                fi
              fi
            '';
          };
          persist-files.deps = [ "credential-secret" ];
        };
      };
    };
}
