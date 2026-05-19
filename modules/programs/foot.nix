{
  flake.modules.homeManager.foot =
    { pkgs, ... }:
    let
      foot-theme = pkgs.fetchurl {
        url = "https://codeberg.org/dnkl/foot/raw/branch/master/themes/moonfly";
        hash = "sha256-u5mARIGsE1CGnlskbfaUcnaSVdxGAQ6Wdn8qyPrC7ew=";
      };
    in
    {
      programs.foot = {
        enable = true;
        server.enable = true;

        settings = {
          main = {
            include = "${foot-theme}";
            term = "xterm-256color";
            font = "BmPlus AST PremiumExec:size=16";
            pad = "4x4";
          };

          scrollback.lines = "16384";
          csd.preferred = "none";
        };
      };
    };
}
