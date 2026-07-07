{ lib, ... }:
{
  flake.modules.nixos.laptop =
    { config, ... }:
    let
      cfg = config.modules.laptop;
      sleepAction = if cfg.suspendThenHibernate.enable then "suspend-then-hibernate" else "suspend";
    in
    {
      options.modules.laptop.suspendThenHibernate.enable =
        lib.mkEnableOption "Hibernate when battery is estimated to drop to 5%";

      config = {
        services = {
          logind.settings.Login = {
            HandleLidSwitch = sleepAction;
            HandleLidSwitchExternalPower = sleepAction;
            HandleLidSwitchDocked = sleepAction;
            HandlePowerKey = sleepAction;
          };

          tuned.enable = true;
          upower.enable = true;
        };

        powerManagement.enable = true;
      };
    };
}
