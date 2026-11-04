{ lib, ... }:
{
  config.flake.factory.user = username: isAdmin: useSecretPassword: {
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

        # A locked password can't answer sudo's prompt.
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

    nixos.secrets =
      { config, lib, ... }:
      let
        user = config.modules.users.${username} or { };
      in
      lib.mkIf (useSecretPassword && (user.enable or false) && !(user.lockPassword or false)) {
        security.nix-secrets.secrets."passwords/${username}".neededForUsers = true;

        users.users.${username} = {
          initialPassword = lib.mkForce null;
          hashedPasswordFile = config.security.nix-secrets.secrets."passwords/${username}".path;
        };
      };
  };
}
