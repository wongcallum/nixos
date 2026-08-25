{ config, lib, ... }:
let
  system = "x86_64-linux";

  # intentionally omitted: staging, minimal-iso, kde-iso
  ciHosts = [
    "acid"
    "liz"
    "salt"
    "shama"
    "vm-coder"
    "vm-gallery"
  ];
in
{
  config.flake.checks.${system} = lib.genAttrs ciHosts (
    hostname: config.flake.nixosConfigurations.${hostname}.config.system.build.toplevel
  );
}
