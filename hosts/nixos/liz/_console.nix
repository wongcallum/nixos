{ config, sshKeys, ... }:
{
  boot = {
    kernelParams = [
      # Keep tty0 available if a maintenance GPU is installed.
      "console=tty0"
      "console=ttyS0,115200"
    ];

    initrd = {
      availableKernelModules = [ "r8169" ];

      network = {
        enable = true;
        ssh = {
          enable = true;
          # Avoid known_hosts collisions with the booted system's SSH host key.
          port = 2222;
          authorizedKeys = sshKeys;
          hostKeys = [ "${config.utils.persistDir}/etc/ssh/initrd_host_ed25519_key" ];
        };
      };
    };
  };
}
