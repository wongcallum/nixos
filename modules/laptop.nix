{
  flake.modules.nixos.laptop = {
    services = {
      logind.settings.Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";
        HandleLidSwitchDocked = "suspend";
        HandlePowerKey = "suspend";
      };

      tuned.enable = true;
      upower.enable = true;
    };

    powerManagement.enable = true;
  };
}
