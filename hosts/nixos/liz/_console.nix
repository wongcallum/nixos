{ config, sshKeys, ... }:
{
  boot = {
    kernelParams = [
      # for a maintenance GPU
      "console=tty0"
      "console=ttyS0,115200"
    ];

    initrd = {
      availableKernelModules = [ "r8169" ];

      network = {
        enable = true;
        ssh = {
          enable = true;
          # avoids known_hosts clashing with the booted system's key
          port = 2222;
          authorizedKeys = sshKeys;
          hostKeys = [ "${config.utils.persistDir}/etc/ssh/initrd_host_ed25519_key" ];
        };
      };
    };
  };
}
