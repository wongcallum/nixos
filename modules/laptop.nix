{
  flake.modules.nixos.laptop = {
    services = {
      logind.settings.Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchDocked = "suspend";
        HandlePowerKey = "suspend";
      };

      tuned.enable = true;
    };

    powerManagement.powertop.enable = true;

    # workaround: tuned-ppd-no-turbo
    # Power saving sets no_turbo=1, which tuned-ppd reports as thermal throttling.
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
}
