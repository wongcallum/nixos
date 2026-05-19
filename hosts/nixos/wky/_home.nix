{ inputs, ... }:
{
  imports = with inputs.self.modules.homeManager; [
    callum

    fonts

    caelestia
    direnv
    git
    zoxide
  ];

  home = {
    stateVersion = "25.11";
  };
}
