{ lib, ... }:
{
  flake.modules.nixos.ssh = {
    modules.ssh.enable = lib.mkDefault true;

    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.PermitRootLogin = "no";
    };
  };

  flake.modules.nixos.persistence =
    { config, ... }:
    {
      environment.persistence.${config.modules.persistence.persistDir}.files =
        lib.mkIf config.modules.ssh.enable
          (
            lib.concatMap (key: [
              key.path
              "${key.path}.pub"
            ]) config.services.openssh.hostKeys
          );
    };
}
