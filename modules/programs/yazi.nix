{
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
