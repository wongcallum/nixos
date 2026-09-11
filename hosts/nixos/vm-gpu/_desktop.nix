{
  config,
  lib,
  pkgs,
  ...
}:
let
  display = ":${toString config.services.xserver.display}";
  xauthority = "/run/xorg/Xauthority";
  inherit (config.services.xserver.displayManager) xserverBin xserverArgs;

  # `cvt 1920 1080 60`
  modeline = ''"1920x1080_60.00"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync'';
in
{
  services = {
    xserver = {
      enable = true;
      displayManager.lightdm.enable = false;
      desktopManager.xfce = {
        enable = true;
        enableScreensaver = false;
      };
      terminateOnReset = false;
      monitorSection = ''
        Modeline ${modeline}
        Option "DPMS" "false"
      '';
      screenSection = ''
        Option "AllowEmptyInitialConfiguration" "true"
        Option "ConnectedMonitor" "DFP"
        Option "UseEDID" "false"
        Option "ModeValidation" "NoMaxPClkCheck, NoEdidMaxPClkCheck, NoMaxSizeCheck, NoHorizSyncCheck, NoVertRefreshCheck, NoVirtualSizeCheck, NoExtendedGpuCapabilitiesCheck, NoTotalSizeCheck, NoDualLinkDVICheck, NoDisplayPortBandwidthCheck, AllowNon3DVisionModes, AllowNonHDMI3DModes, AllowNonEdidModes, NoEdidHDMI2Check"
        Option "MetaModes" "1920x1080_60.00 +0+0"
        Option "HardDPMS" "false"
      '';
    };

    libinput.enable = true;
  };

  powerManagement.enable = false;
  environment.xfce.excludePackages = [ pkgs.xfce4-power-manager ];

  hardware.nvidia.nvidiaSettings = false;

  users.users.callum = {
    linger = true;
    extraGroups = [
      "video"
      "render"
    ];
  };

  environment.persistence.${config.modules.persistence.persistDir}.directories = [
    {
      directory = "/home/callum";
      user = "callum";
      group = "users";
      mode = "0700";
    }
  ];

  systemd.services = {
    xorg = {
      description = "Headless Xorg on ${display}";
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        rm -f ${xauthority}
        ${lib.getExe pkgs.xauth} -q -f ${xauthority} add ${display} . "$(${lib.getExe' pkgs.util-linux "mcookie"})"
        chown callum ${xauthority}
        chmod 0400 ${xauthority}
      '';

      postStart = ''
        for _ in $(seq 1 100); do
          if XAUTHORITY=${xauthority} ${lib.getExe pkgs.xset} -display ${display} q >/dev/null 2>&1; then
            exit 0
          fi
          sleep 0.1
        done
        echo "Xorg did not come up on ${display}" >&2
        exit 1
      '';

      serviceConfig = {
        RuntimeDirectory = "xorg";
        RuntimeDirectoryMode = "0755";
        ExecStart = "${xserverBin} ${toString xserverArgs} -auth ${xauthority} -noreset vt7";
        Restart = "always";
        RestartSec = 2;
      };
    };

    xfce-session = {
      description = "XFCE session for callum on ${display}";
      wantedBy = [ "multi-user.target" ];
      bindsTo = [ "xorg.service" ];
      after = [
        "xorg.service"
        "systemd-user-sessions.service"
      ];

      environment = {
        DISPLAY = display;
        XAUTHORITY = xauthority;
        XDG_SESSION_TYPE = "x11";
      };

      serviceConfig = {
        User = "callum";
        Group = "users";
        PAMName = "login";
        WorkingDirectory = "/home/callum";
        ExecStart = "${config.services.displayManager.sessionData.wrapper} ${lib.getExe' pkgs.xfce4-session "startxfce4"}";
        Restart = "always";
        RestartSec = 2;
      };
    };
  };
}
