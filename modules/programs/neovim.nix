{
  flake.modules.homeManager.neovim = {
    programs.neovim = {
      enable = true;
      withRuby = false;
      withPython3 = false;
    };
  };
}
