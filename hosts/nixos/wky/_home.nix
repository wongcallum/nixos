{ inputs, ... }:
{
  imports = with inputs.self.modules.homeManager; [
    callum

    fonts

    delta
    direnv
    fish
    foot
    git
    mise
    neovim
    noctalia
    vscode
    yazi
    zoxide
  ];

  home = {
    sessionVariables.EDITOR = "nvim";

    file.".config/niri".source = ./configs/niri;

    stateVersion = "25.11";
  };
}
