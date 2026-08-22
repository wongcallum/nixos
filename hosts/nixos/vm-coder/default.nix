{ config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixpkgs.vm-coder = "unstable";

  flake.modules.nixos."hosts/nixos/vm-coder" = {
    imports = [ nixos.coder ];

    microvm.mem = 8192;

    system.stateVersion = "25.11";
  };
}
