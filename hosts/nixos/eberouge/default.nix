{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.modules.nixos."hosts/nixos/eberouge" =
    { modulesPath, ... }:
    {
      imports = [
        ./_disko.nix

        (modulesPath + "/profiles/qemu-guest.nix")
        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        zram

        btrfs-rollback
        persistence

        callum

        ssh
        tailscale
      ]);

      system.stateVersion = "26.05";

      # kexec runs out of memory on 1 GB, so install by importing this image.
      disko.imageBuilder.imageFormat = "qcow2";

      boot = {
        loader = {
          systemd-boot.enable = true;
          # The firmware boots the removable path, so no NVRAM entry is needed.
          efi.canTouchEfiVariables = false;
        };
        # OCI's serial console reads ttyS0.
        kernelParams = [
          "console=tty1"
          "console=ttyS0"
        ];
      };

      modules.users.callum.lockPassword = true;

      networking.useNetworkd = true;
      systemd.network = {
        enable = true;
        networks."10-eth" = {
          matchConfig.Type = "ether";
          networkConfig.DHCP = "ipv4";
          linkConfig.RequiredForOnline = "routable";
        };
      };
    };
}
