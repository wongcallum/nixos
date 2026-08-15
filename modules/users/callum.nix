{
  self,
  config,
  lib,
  ...
}:
let
  inherit (config.flake) keys;
in
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
            openssh.authorizedKeys.keys = keys.callum;
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
