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
              # losing it strands every systemd credential
              credentialSecret
            ];
        };

        # systemd would replace impermanence's symlink to a missing key, so seed it
        system.activationScripts = {
          credential-secret = {
            # the key is bound to the machine-id, which needs /etc set up
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
                  # on a fresh root the persisted machine-id isn't mounted yet
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
