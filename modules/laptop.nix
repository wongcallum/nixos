{
  flake.modules.nixos.laptop = {
    services = {
      logind.settings.Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "ignore";
        HandleLidSwitchDocked = "ignore";
      };

      tuned.enable = true;
      upower.enable = true;
    };

    powerManagement.enable = true;
  };
}
