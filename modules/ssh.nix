{
  flake.modules.nixos.ssh = {
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.PermitRootLogin = "no";
    };
  };

  flake.modules.nixos.persistence =
    { lib, config, ... }:
    {
      # by default, /etc/ssh/ssh_host_rsa_key and /etc/ssh/ssh_host_ed25519_key
      environment.persistence.${config.modules.persistence.persistDir}.files = lib.concatMap (key: [
        key.path
        "${key.path}.pub"
      ]) config.services.openssh.hostKeys;
    };
}
