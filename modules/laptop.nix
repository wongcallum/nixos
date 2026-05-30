{
  flake.modules.nixos.laptop = {
    services = {
      logind.settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
        HandleLidSwitchDocked = "ignore";
        HandlePowerKey = "suspend";
      };

      tuned.enable = true;
      upower.enable = true;
    };

    powerManagement.enable = true;
  };
}
