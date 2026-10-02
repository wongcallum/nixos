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
          files = [
            "/etc/machine-id"
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
            deps = [ "createPersistentStorageDirs" ];
            text = ''
              persisted=${persistDir}${credentialSecret}
              live=${credentialSecret}
              if [ ! -e "$persisted" ]; then
                mkdir -p "$(dirname "$persisted")"
                if [ -s "$live" ] && [ ! -L "$live" ] && ! ${pkgs.util-linux}/bin/findmnt "$live" >/dev/null; then
                  mv "$live" "$persisted"
                else
                  rm -f "$live"
                  SYSTEMD_CREDENTIAL_SECRET="$persisted" ${config.systemd.package}/bin/systemd-creds setup
                fi
              fi
            '';
          };
          persist-files.deps = [ "credential-secret" ];
        };
      };
    };
}
