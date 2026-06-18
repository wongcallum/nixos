{
  flake.modules.nixos.zoxide = {
    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
