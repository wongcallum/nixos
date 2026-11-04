{ inputs, ... }:
{
  flake.modules.nixos.secrets =
    { config, lib, ... }:
    let
      cfg = config.security.nix-secrets;
      encFile = secret: cfg.storage + "/${secret.name}.enc";
      restarts = lib.filterAttrs (_: s: s.enable && s.restartUnits != [ ]) cfg.secrets;
    in
    {
      imports = [ inputs.nix-secrets.nixosModules.default ];

      # workaround: nix-secrets-restart-units
      options.security.nix-secrets.secrets = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.restartUnits = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Units to restart when the secret's encrypted file changes.";
            };
          }
        );
      };

      config = {
        security.nix-secrets = {
          enable = true;
          storage = inputs.secrets;
          storagePath = "/home/callum/code/nixos-secrets";
          identityPaths = [
            "${config.utils.persistDir}/etc/ssh/ssh_host_ed25519_key"
            "/home/callum/.config/sops/age/keys.txt"
          ];
          recipientAliases = {
            callum = [
              "age1yfhmmmchummwg582vskf6f4wzy3uwrlygtjgr93qu0r4yrkdqvhsvxg3yh"
              "age1ykg57f32d7ragxvwxcpu0wuysupz9kc5nt66v2e4865qkkjv696qs5dak7"
            ];
            liz = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0RmYquUGDKZ0YK22IbfUoa8BStIls3p0hoFx1iSpTS";
            salt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5o7rndzzxeoHR/LETsL3juQAZClv90eZ8j1j9Q3ebF";
            eberouge = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOWTAAbkjTRkisqJf/6sQTO+4eO4fepneZPH7JgQ/bjO";
            vm-gallery = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpEZOQZwJ3cRNhpP4I0JeItjUPEKvU2SobD8BMEHvBJ";
            vm-thsconline = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEt4f9wshu5jTW2+G0UyPMnvmX9CsMi/MpyARtZuWLBT";
            vm-ci = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEp2GceFAJuovixjsm2uicrS3iVzCf5k2cD77dmr7Kx1";
            homelab = [
              "liz"
              "salt"
              "eberouge"
              "vm-gallery"
              "vm-thsconline"
            ];
          };
          # Recipients must match on every host sharing a secret, or rekeying from one host locks out the others.
          defaultRecipients = [
            "callum"
            "homelab"
          ];
        };

        # workaround: nix-secrets-restart-units
        system.activationScripts.nixSecretsRestartUnits = lib.mkIf (restarts != { }) {
          deps = [ "nixSecretsActivate" ];
          supportsDryActivation = false;
          text = ''
            mkdir -p /run/nix-secrets-restart
            ${lib.concatMapStrings (
              s:
              let
                stamp = "/run/nix-secrets-restart/${builtins.hashString "sha256" s.name}";
                hash = if builtins.pathExists (encFile s) then builtins.hashFile "sha256" (encFile s) else "";
              in
              ''
                if [ -e ${stamp} ] && [ "$(cat ${stamp})" != ${hash} ]; then
                  printf '%s\n' ${lib.escapeShellArgs s.restartUnits} >> /run/nixos/activation-restart-list
                fi
                echo ${hash} > ${stamp}
              ''
            ) (lib.attrValues restarts)}
          '';
        };
      };
    };
}
