{ config, sshKeys, ... }:
{
  boot = {
    kernelParams = [
      # Keeps tty0 for a maintenance GPU.
      "console=tty0"
      "console=ttyS0,115200"
    ];

    initrd = {
      availableKernelModules = [ "r8169" ];

      network = {
        enable = true;
        ssh = {
          enable = true;
          # A separate port keeps known_hosts from clashing with the booted system's key.
          port = 2222;
          authorizedKeys = sshKeys;
          hostKeys = [ "${config.utils.persistDir}/etc/ssh/initrd_host_ed25519_key" ];
        };
      };
    };
  };
}
