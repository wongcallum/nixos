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
            Root for caches that are expensive to rebuild, kept out of persistDir
            and its backups. Impermanent hosts wipe the default at boot. Point it
            at a dedicated dataset to keep caches across reboots.
          '';
        };
      };

      config = {
        fileSystems.${persistDir}.neededForBoot = true;

        # Activation copies the persisted copy's mode onto /var/lib/private, and
        # DynamicUser services refuse to start unless it's 0700.
        systemd.tmpfiles.rules = [
          "d /var/lib/private 0700 root root -"
          "d ${persistDir}/var/lib/private 0700 root root -"
        ];

        environment.persistence.${persistDir} = {
          enable = true;
          hideMounts = true;
          directories = [
            "/var/lib/nixos"
            "/var/log"
          ];
          files =
            # A declared machine-id, as microvm.nix sets, is already stable.
            lib.optional (!(config.environment.etc ? "machine-id")) "/etc/machine-id" ++ [
              # Losing it strands every systemd credential.
              credentialSecret
            ];
        };

        # systemd replaces impermanence's symlink to a missing key, so the key would
        # never persist. Seed it first.
        system.activationScripts = {
          credential-secret = {
            # systemd-creds binds the key to the machine-id, which needs /etc set up.
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
                  # On a fresh root, persist-files hasn't mounted the machine-id yet.
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
