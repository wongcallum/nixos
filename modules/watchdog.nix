{
  flake.modules.nixos.watchdog =
    {
      lib,
      config,
      ...
    }:
    {
      options.modules.watchdog = {
        driver = lib.mkOption {
          type = lib.types.str;
          example = "siTCO_wdt";
          description = "Kernel module for the board's watchdog timer";
        };

        runtimeTime = lib.mkOption {
          type = lib.types.str;
          default = "60s";
          description = "How long PID 1 may go before the board resets";
        };
      };

      config = {
        boot.initrd.kernelModules = [ config.modules.watchdog.driver ];

        systemd.settings.Manager.RuntimeWatchdogSec = config.modules.watchdog.runtimeTime;
      };
    };
}
