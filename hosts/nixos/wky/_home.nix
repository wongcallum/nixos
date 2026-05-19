{ inputs, ... }:
{
  imports = with inputs.self.modules.homeManager; [
    callum

    fonts

    direnv
    git
    noctalia
    zoxide
  ];

  home = {
    stateVersion = "25.11";
  };
}
