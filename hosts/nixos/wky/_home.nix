{ inputs, ... }:
{
  imports = with inputs.self.modules.homeManager; [
    callum

    fonts

    direnv
    git
    zoxide
  ];

  home = {
    stateVersion = "25.11";
  };
}
