{ lib, ... }:
{
  options.flake.keys = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
    default = { };
    description = "SSH public keys per user, shared between host configs and the installer ISO";
  };

  config.flake.keys.callum = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMP4bm4SjbUcveDfeNVU7QkWz/pFWuVrPsZIa5e6ZE64 callum@acid"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInBiS3lc/8BUJLibu1+6KSu+pEOLXPCRxY/FLF5GMo5 callum@shama"
  ];
}
