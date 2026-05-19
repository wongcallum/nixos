{
  flake.modules.homeManager.fish =
    { pkgs, ... }:
    {
      programs.fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting "We thirst for the seven wailings. We bear the koan of Jericho."
        '';
        plugins = [
          {
            name = "autopair";
            src = pkgs.fishPlugins.autopair.src;
          }
        ];
      };
    };
}
