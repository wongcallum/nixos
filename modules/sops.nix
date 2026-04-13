{ inputs, ... }:
let
  secretsPath = toString inputs.secrets;
in
{
  flake.modules.nixos.sops =
    { config, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      sops = {
        defaultSopsFile = "${secretsPath}/secrets.yaml";
        age.sshKeyPaths = [ "${config.utils.persistDir}/etc/ssh/ssh_host_ed25519_key" ];
      };
    };
}
