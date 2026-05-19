{
  flake.modules.homeManager.direnv = {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      mise.enable = true;
      enableFishIntegration = true;
    };
  };
}
