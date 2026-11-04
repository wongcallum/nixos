{
  flake.modules.nixos.thunderbird =
    { config, pkgs, ... }:
    {
      programs.thunderbird = {
        enable = true;
        package = pkgs.wrapThunderbird pkgs.thunderbird-unwrapped {
          nativeMessagingHosts = config.programs.firefox.nativeMessagingHosts.packages;
        };
      };
    };
}
