{ config, inputs, ... }:
let
  hosts = config.flake.nixosConfigurations;
  hostKeys = {
    liz = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0RmYquUGDKZ0YK22IbfUoa8BStIls3p0hoFx1iSpTS";
    salt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5o7rndzzxeoHR/LETsL3juQAZClv90eZ8j1j9Q3ebF";
    eberouge = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOWTAAbkjTRkisqJf/6sQTO+4eO4fepneZPH7JgQ/bjO";
    vm-gallery = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpEZOQZwJ3cRNhpP4I0JeItjUPEKvU2SobD8BMEHvBJ";
    vm-thsconline = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEt4f9wshu5jTW2+G0UyPMnvmX9CsMi/MpyARtZuWLBT";
    vm-ci = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEp2GceFAJuovixjsm2uicrS3iVzCf5k2cD77dmr7Kx1";
  };
in
{
  flake.modules.nixos.secrets =
    { config, lib, ... }:
    let
      hostname = config.networking.hostName;
      cfg = config.security.nix-secrets;
      encFile = secret: cfg.storage + "/${secret.name}.enc";
      enabled = lib.filterAttrs (_: s: s.enable) cfg.secrets;
      restarts = lib.filterAttrs (_: s: s.restartUnits != [ ]) enabled;
      # Every host gets the same recipients for a secret, so rekeying from any host's config agrees.
      usedBy =
        name:
        lib.filter (h: hosts.${h}.config.security.nix-secrets.secrets.${name}.enable or false) (
          lib.attrNames hostKeys
        );
      wanted = map (s: "${s.name}.enc") (lib.attrValues enabled);
    in
    {
      imports = [ inputs.nix-secrets.nixosModules.default ];

      options.security.nix-secrets.secrets = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { config, ... }:
            {
              # workaround: nix-secrets-restart-units
              options.restartUnits = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Units to restart when the secret's encrypted file changes.";
              };

              config.recipients = usedBy config.name;
            }
          )
        );
      };

      config = {
        assertions = [
          {
            assertion = enabled == { } || hostKeys ? ${hostname};
            message = "${hostname} uses nix-secrets but has no key in modules/secrets.nix.";
          }
        ];

        security.nix-secrets = {
          enable = true;
          storage = builtins.path {
            name = "secrets";
            path = inputs.secrets;
            filter =
              path: type: type == "directory" || lib.elem (lib.removePrefix "${inputs.secrets}/" path) wanted;
          };
          storagePath = "/home/callum/code/nixos-secrets";
          identityPaths = [
            "${config.utils.persistDir}/etc/ssh/ssh_host_ed25519_key"
            "/home/callum/.config/sops/age/keys.txt"
          ];
          recipientAliases = hostKeys // {
            callum = [
              "age1yfhmmmchummwg582vskf6f4wzy3uwrlygtjgr93qu0r4yrkdqvhsvxg3yh"
              "age1ykg57f32d7ragxvwxcpu0wuysupz9kc5nt66v2e4865qkkjv696qs5dak7"
            ];
          };
          defaultRecipients = [ "callum" ];
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
