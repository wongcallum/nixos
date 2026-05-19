{ inputs, ... }:
{
  flake.modules.nixos.yazi = {
    nixpkgs.overlays = [ inputs.yazi.overlays.default ];

    nix.settings = {
      extra-substituters = [ "https://yazi.cachix.org" ];
      extra-trusted-public-keys = [ "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k=" ];
    };
  };

  flake.modules.homeManager.yazi = {
    programs.yazi = {
      enable = true;
      enableFishIntegration = true;
      shellWrapperName = "y";

      # disable nerd fonts
      theme = {
        status = {
          sep_left = {
            open = "";
            close = "";
          };
          sep_right = {
            open = "";
            close = "";
          };
        };

        icon = {
          globs = [ ];
          dirs = [ ];
          files = [ ];
          exts = [ ];
          conds = [ ];
        };

        indicator.padding = {
          open = "";
          close = "";
        };
      };
    };
  };
}
