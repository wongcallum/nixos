{ config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixpkgs.vm-coder = "unstable";

  flake.modules.nixos."hosts/nixos/vm-coder" = {
    imports = [ nixos.coder ];

    system.stateVersion = "25.11";
  };
}
