{
  self,
  config,
  lib,
  ...
}:
{
  flake.modules = lib.mkMerge [
    (self.factory.user "colin" true true)
    {
      nixos.colin.users.users.colin.openssh.authorizedKeys.keys = config.flake.keys.colin;
    }
  ];
}
