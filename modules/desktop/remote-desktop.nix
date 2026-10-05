{ inputs, ... }:
{
  # A login-less streaming appliance: a headless sway session that punktfunk
  # serves to clients. Hosts supply the GPU driver.
  flake.modules.nixos.remote-desktop =
    {
      config,
      lib,
      ...
    }:
    let
      user = "callum";
      nvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
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

      # Also routes ScreenCast to xdg-desktop-portal-wlr and exports SWAYSOCK and
      # WAYLAND_DISPLAY to the user manager, where punktfunk finds them.
      programs.sway.enable = true;

      # NixOS starts xdg-desktop-portal-wlr with --config, so it ignores the
      # chooser punktfunk writes to ~/.config and waits on an interactive slurp.
      # This is that chooser: punktfunk names each session's output in the file.
      xdg.portal.wlr.settings.screencast = {
        chooser_type = "simple";
        chooser_cmd = "cat $XDG_RUNTIME_DIR/punktfunk-xdpw-output";
      };

      services = {
        pipewire = {
          enable = true;
          pulse.enable = true;
        };

        # Each client gets a `swaymsg create_output` headless output at its own mode.
        punktfunk.host = {
          enable = true;
          users = [ user ];
          autoStart = true;
          openFirewall = true;
          # The host starts before sway exports its environment, and input
          # injection reads only WAYLAND_DISPLAY. sway is the user's only
          # compositor, so it always takes the first socket, wayland-1.
          settings = {
            WAYLAND_DISPLAY = "wayland-1";
            XDG_CURRENT_DESKTOP = "sway";
            PUNKTFUNK_COMPOSITOR = "wlroots";
            PUNKTFUNK_VIDEO_SOURCE = "virtual";
            PUNKTFUNK_INPUT_BACKEND = "wlr";
            PUNKTFUNK_GSO = true;
          };
        };
      };

      # Upstream's scripts/headless/run-headless-sway.sh as a unit, started at
      # boot through lingering.
      systemd.user.services.punktfunk-sway-session = {
        description = "punktfunk headless sway session";
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
        environment = lib.mkMerge [
          {
            XDG_CURRENT_DESKTOP = "sway";
            XDG_SESSION_TYPE = "wayland";
            WLR_BACKENDS = "headless";
            # No bootstrap HEADLESS-1: it would hold workspace 1 off-stream.
            # With no outputs, sway parks workspaces until a client's output appears.
            WLR_HEADLESS_OUTPUTS = "0";
            WLR_LIBINPUT_NO_DEVICES = "1";
          }
          # Upstream's wlroots-on-NVIDIA settings from scripts/headless/env.sh.
          (lib.mkIf nvidia {
            WLR_RENDERER = "gles2";
            WLR_NO_HARDWARE_CURSORS = "1";
            GBM_BACKEND = "nvidia-drm";
            __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          })
        ];
        serviceConfig = {
          ExecStart = "${lib.getExe config.programs.sway.package}${lib.optionalString nvidia " --unsupported-gpu"}";
          Restart = "always";
          RestartSec = 3;
        };
      };
    };
}
