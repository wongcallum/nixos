{
  flake.modules.nixos.sensors =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      options.modules.sensors.chips = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "nct6775" ];
        description = "Super-I/O hwmon drivers the board needs for fan and voltage sensors";
      };

      config = {
        # Super-I/O chips sit behind IO ports ACPI claims, so the kernel never
        # probes them on its own and the board's driver has to be named.
        boot.kernelModules = config.modules.sensors.chips;

        # node_exporter's hwmon collector picks the chip up on its own.
        environment.systemPackages = [ pkgs.lm_sensors ];
      };
    };
}
