{ inputs, ... }:
{
  # A login-less streaming appliance: a headless Plasma session that punktfunk
  # serves to clients. Hosts supply the GPU driver.
  flake.modules.nixos.remote-desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      user = "callum";
      punktfunk = config.services.punktfunk.host.package;
    in
    {
      imports = [ inputs.punktfunk.nixosModules.default ];

      hardware.graphics.enable = true;

      users.users.${user} = {
        linger = true;
        extraGroups = [
          "video"
          "render"
          "uinput"
        ];
      };

      services = {
        # With no display manager, punktfunk-kde-session below runs Plasma.
        desktopManager.plasma6.enable = true;

        pipewire = {
          enable = true;
          pulse.enable = true;
        };

        # Each client gets a KWin virtual output at its own mode.
        punktfunk.host = {
          enable = true;
          users = [ user ];
          autoStart = true;
          openFirewall = true;
          # Pinned to the headless session, as in upstream's packaging/kde/host.env.
          settings = {
            WAYLAND_DISPLAY = "wayland-kde";
            XDG_CURRENT_DESKTOP = "KDE";
            PUNKTFUNK_COMPOSITOR = "kwin";
            PUNKTFUNK_VIDEO_SOURCE = "virtual";
            PUNKTFUNK_INPUT_BACKEND = "libei";
            PUNKTFUNK_GSO = true;
            PUNKTFUNK_KWIN_VIRTUAL_PRIMARY = true;
          };
        };
      };

      # Upstream's headless Plasma session: `kwin --virtual` plus plasmashell,
      # started at boot through lingering.
      systemd.user.services.punktfunk-kde-session = {
        description = "punktfunk headless KDE Plasma session";
        unitConfig.ConditionUser = user;
        wantedBy = [ "default.target" ];
        after = [
          "pipewire.service"
          "pipewire-pulse.service"
          "dbus.service"
        ];
        wants = [ "pipewire.service" ];
        # inherit the user manager's login PATH, not NixOS's minimal unit default.
        enableDefaultPath = false;
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.bash} ${punktfunk}/share/punktfunk-host/headless/run-headless-kde.sh 1920x1080";
          Restart = "always";
          RestartSec = 3;
        };
      };
    };
}
