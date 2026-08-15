# Getting at liz when it will not boot.
#
# After the board swap liz runs a Ryzen 5 5600 — a non-G part with no integrated
# graphics — and its only GPU is the RTX 3060, which _vfio.nix binds away at boot
# for the Windows guest. There is therefore no display device on the machine at
# all, and no room for a console card either: PCIEX16_1 holds the 3060, PCIEX16_2
# holds the LSI HBA, and populating any x1 slot drops PCIEX16_2 to a single lane
# (per the TUF B550-PLUS manual), which would strangle six drives. Two cards is
# the hard ceiling.
#
# So the console has to come over the wire. Two independent nets, because they
# fail in different places:
#
#   initrd SSH — a shell when the root pool will not import, the single most
#     likely way this machine fails to come up. Free, but useless before initrd.
#   serial     — the B550-PLUS has a COM header (manual item 13). Covers the
#     kernel, initrd and all of systemd. Does *not* cover BIOS or the
#     systemd-boot menu: both render to the EFI console and consumer boards do
#     not do BIOS serial redirection. If you ever need to pick an older
#     generation from the boot menu remotely, that needs a KVM-over-IP.
{ config, sshKeys, ... }:
{
  boot = {
    kernelParams = [
      # tty0 stays first so a monitor still works if one is ever plugged into a
      # card during maintenance; ttyS0 is the one that matters day to day.
      "console=tty0"
      "console=ttyS0,115200"
    ];

    initrd = {
      # r8169 drives the board's Realtek 2.5GbE. It has to be in the initrd or
      # the emergency shell below has no network to be reached over.
      availableKernelModules = [ "r8169" ];

      network = {
        enable = true;
        ssh = {
          enable = true;
          # Deliberately not 22: initrd and the booted system present different
          # host keys, and sharing a port makes known_hosts fight itself.
          port = 2222;
          authorizedKeys = sshKeys;
          # Generate once, by hand, before the first boot that relies on this:
          #   ssh-keygen -t ed25519 -N "" -f /persist/etc/ssh/initrd_host_ed25519_key
          hostKeys = [ "${config.utils.persistDir}/etc/ssh/initrd_host_ed25519_key" ];
        };
      };
    };
  };
}
