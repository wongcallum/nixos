{
  flake.modules.nixos.bluetooth = {
    hardware.bluetooth.enable = true;
    hardware.enableAllFirmware = true;
  };
}
