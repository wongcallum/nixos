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
        # the kernel never probes Super-I/O chips behind ACPI-claimed ports
        boot.kernelModules = config.modules.sensors.chips;

        environment.systemPackages = [ pkgs.lm_sensors ];
      };
    };
}
