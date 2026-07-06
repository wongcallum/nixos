{
  # explicitly forward DISPLAY and XAUTHORITY for both apps which escalate via `pkexec`
  flake.modules.nixos.disk-utils =
    { pkgs, lib, ... }:
    let
      env = lib.getExe' pkgs.coreutils "env";
    in
    {
      environment.systemPackages = [
        (pkgs.gparted.overrideAttrs (old: {
          postFixup = (old.postFixup or "") + ''
            chmod u+w $out/bin/.gparted-wrapped
            substituteInPlace $out/bin/.gparted-wrapped \
              --replace-fail \
                'pkexec --disable-internal-agent ' \
                'pkexec --disable-internal-agent ${env} DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" '
          '';
        }))

        (pkgs.gsmartcontrol.overrideAttrs (old: {
          postFixup = (old.postFixup or "") + ''
            chmod u+w $out/bin/gsmartcontrol-root
            substituteInPlace $out/bin/gsmartcontrol-root \
              --replace-fail \
                'pkexec --disable-internal-agent $EXEC_BIN' \
                'pkexec --disable-internal-agent ${env} DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY $EXEC_BIN'
          '';
        }))
      ];
    };
}
