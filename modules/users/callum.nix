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
              "no-pty ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH+hBUksJQH8d/bXoDfZ+AzohvjBNM8CHZS9SqEApeiE root@wky"
            ];
            extraGroups = lib.mkMerge [
              (lib.optionals config.virtualisation.libvirtd.enable [ "libvirtd" ])
              (lib.optionals config.virtualisation.docker.enable [ "docker" ])
            ];
          };
          programs.fish.enable = true;
        };
    }
  ];
}
