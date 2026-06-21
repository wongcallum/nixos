{ inputs, ... }:
{
  flake.modules.nixos.ghostty =
    { pkgs, ... }:
    let
      ghostty = inputs.ghostty.packages.${pkgs.system}.default;
    in
    {
      environment.systemPackages = [ ghostty ];

      systemd.packages = [ ghostty ];

      # warm first start :)
      systemd.user.services."app-com.mitchellh.ghostty" = {
        overrideStrategy = "asDropin";
        wantedBy = [ "graphical-session.target" ];
      };
    };
}
