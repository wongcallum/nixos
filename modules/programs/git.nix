{
  flake.modules.homeManager.git = {
    programs.git.enable = true;

    programs.delta = {
      enable = true;
      enableGitIntegration = true;
    };
  };
}
