{ inputs, ... }:
{
  flake.modules.nixos.noctalia =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };

  flake.modules.homeManager.noctalia = {
    imports = [ inputs.noctalia.homeModules.default ];
    programs.noctalia-shell.enable = true;
  };
}
