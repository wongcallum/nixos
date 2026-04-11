let
  username = "callum";
in
{
  flake.modules.nixos.${username} =
    { pkgs, ... }:
    {
      users.users.${username} = {
        isNormalUser = true;
        home = "/home/${username}";
        extraGroups = [
          "wheel"
        ];
        shell = pkgs.fish;
        initialPassword = "changeme";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMP4bm4SjbUcveDfeNVU7QkWz/pFWuVrPsZIa5e6ZE64 callum@acid"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINw8zK93i7WJYfbmpcXE5ZYTWRvkm3ohIdsvWmWOkCFQ callum@wky"
        ];
      };
      programs.fish.enable = true;
      nix.settings.trusted-users = [ username ];
    };
}
