{ inputs, ... }:
{
  flake.modules.homeManager.caelestia = {
    imports = [ inputs.caelestia-shell.homeManagerModules.default ];

    programs.caelestia = {
      enable = true;
      systemd = {
        enable = true;
        target = "graphical-session.target";
        environment = [ ];
      };
      settings = {
        paths.wallpaperDir = "~/Pictures/Wallpapers";
      };
      cli = {
        enable = true;
      };
    };
  };
}
