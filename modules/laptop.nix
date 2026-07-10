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

        # tuned-ppd thinks that no_turbo=1 means that the cpu is thermal throttling
        # we automatically disable turbo in the power saving profile, so the report is misleading
        # only report PerformanceDegraded="high-operating-temperature" if using the performance profile
        nixpkgs.overlays = [
          (_final: prev: {
            tuned = prev.tuned.overrideAttrs (old: {
              postPatch = (old.postPatch or "") + ''
                substituteInPlace tuned/ppd/controller.py \
                  --replace-fail \
                    'if os.path.exists(NO_TURBO_PATH) and self._cmd.read_file(NO_TURBO_PATH).strip() == "1":' \
                    'if self._active_profile == PPD_PERFORMANCE and os.path.exists(NO_TURBO_PATH) and self._cmd.read_file(NO_TURBO_PATH).strip() == "1":'
              '';
            });
          })
        ];
      };
    };
}
