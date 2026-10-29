{ lib, pkgs, ... }:
let
  pageRoot = "/srv/www";
  pageAddr = "127.0.0.1:8080";

  # Override
  urlFile = "/var/lib/kiosk/url";

  browser = pkgs.writeShellScript "kiosk-browser" ''
    url="http://${pageAddr}/"
    if [ -r ${urlFile} ]; then
      url=$(< ${urlFile})
    fi
    exec ${
      lib.concatStringsSep " " [
        (lib.getExe pkgs.chromium)
        "--kiosk"
        "--ozone-platform=wayland"
        "--no-first-run"
        "--noerrdialogs"
        "--disable-session-crashed-bubble"
        "--disable-infobars"
        "--disable-translate"
        "--password-store=basic"
        "--check-for-update-interval=31536000"
      ]
    } --app="$url"
  '';
in
{
  users.users.kiosk.isNormalUser = true;

  hardware.graphics.enable = true;

  services.cage = {
    enable = true;
    user = "kiosk";
    # -d: no client-side decorations
    extraArguments = [ "-d" ];
    program = browser;
  };

  services.static-web-server = {
    enable = true;
    listen = pageAddr;
    root = pageRoot;
    configuration = {
      general.cache-control-headers = false;
      advanced.headers = [
        {
          source = "**";
          headers.Cache-Control = "no-cache";
        }
      ];
    };
  };

  systemd = {
    services."cage-tty1" = {
      serviceConfig.Restart = "always";
      serviceConfig.RestartSec = 5;
    };

    targets.getty.wants = lib.mkForce [ ];

    tmpfiles.rules = [
      "d ${pageRoot} 0755 callum users -"
      "d /var/lib/kiosk 0700 kiosk users -"
    ];
  };
}
