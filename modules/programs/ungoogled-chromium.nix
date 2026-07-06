{
  flake.modules.nixos.ungoogled-chromium =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        (pkgs.ungoogled-chromium.override {
          # run natively on Wayland instead of XWayland
          commandLineArgs = "--ozone-platform-hint=auto";
        })
      ];
    };
}
