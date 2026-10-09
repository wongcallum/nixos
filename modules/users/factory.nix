{ lib, ... }:
{
  config.flake.factory.user = username: isAdmin: useSopsPassword: {
    nixos."${username}" =
      { config, ... }:
      {
        modules.users.${username}.enable = true;

        users.users."${username}" = lib.mkMerge [
          {
            isNormalUser = true;
            home = "/home/${username}";
            extraGroups = lib.optionals isAdmin [ "wheel" ];
          }
          (lib.mkIf config.modules.users.${username}.lockPassword {
            initialPassword = lib.mkForce null;
            hashedPassword = "!";
          })
        ];

        nix.settings.trusted-users = lib.optionals isAdmin [ username ];

        # a locked password can't answer sudo's prompt
        security.sudo.extraRules = lib.mkIf (isAdmin && config.modules.users.${username}.lockPassword) [
          {
            users = [ username ];
            commands = [
              {
                command = "ALL";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
      };

    nixos.sops =
      { config, lib, ... }:
      let
        user = config.modules.users.${username} or { };
      in
      lib.mkIf (useSopsPassword && (user.enable or false) && !(user.lockPassword or false)) {
        sops.secrets."passwords/${username}" = {
          owner = "root";
          group = "root";
          mode = "0400";
          neededForUsers = true;
        };

        users.users.${username} = {
          initialPassword = lib.mkForce null;
          hashedPasswordFile = config.sops.secrets."passwords/${username}".path;
        };
      };
  };
}
