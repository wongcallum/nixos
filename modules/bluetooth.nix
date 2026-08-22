{
  flake.modules.nixos.bluetooth = { pkgs, ... }: {
    hardware.bluetooth.enable = true;
    hardware.enableAllFirmware = true;

    environment.systemPackages = [
      pkgs.blueman
    ];
  };
}
