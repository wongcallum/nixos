{ lib, ... }:
{
  flake.modules.nixos.ssh = {
    modules.ssh.enable = lib.mkDefault true;

    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.PermitRootLogin = "no";

      # FIXME: probably insecure
      extraConfig = ''
        Match Address 192.168.122.0/24
            PasswordAuthentication yes
      '';
    };

    # otherwise only enabled when PasswordAuthentication is globally true
    security.pam.services.sshd.unixAuth = lib.mkForce true;
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
