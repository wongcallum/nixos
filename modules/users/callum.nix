{ self, lib, ... }:
{
  flake.modules = lib.mkMerge [
    (self.factory.user "callum" true true)
    {
      nixos.callum =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          users.users.callum = {
            shell = pkgs.fish;
            initialPassword = "changeme";
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMP4bm4SjbUcveDfeNVU7QkWz/pFWuVrPsZIa5e6ZE64 callum@acid"
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDCd6wji8oxyVnqDq3I5qMTOfNJ8Z/Rm/eGfismjUL4 callum@wky"
            ];
            extraGroups = lib.optionals config.virtualisation.libvirtd.enable [ "libvirtd" ];
          };
          programs.fish.enable = true;
        };

      homeManager.callum =
        { pkgs, ... }:
        {
          home = {
            username = "callum";
            homeDirectory = "/home/callum";
            packages = [ pkgs.neovim ];
            sessionVariables.EDITOR = "nvim";
          };

          programs.git.settings = {
            user.name = "callum";
            user.email = "mail@callumwong.com";
          };
        };
    }
  ];
}
