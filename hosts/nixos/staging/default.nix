{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixpkgs.staging = "unstable";

  flake.modules.nixos."hosts/nixos/staging" =
    { modulesPath, ... }:
    {
      imports = [
        ./_disko.nix
        ./_remote-desktop.nix
        ./_audio-dummy.nix
        ./_dotfiles.nix
        ../shama/_packages.nix

        (modulesPath + "/profiles/qemu-guest.nix")

        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        uefi
        impermanence-zfs
        persistence
        zram

        callum

        ssh
        tailscale

        audio
        desktop
        niri
        fonts
        firefox
        ghostty
        nix-ld
        direnv
        zoxide
      ]);

      system.stateVersion = "25.11";

      networking = {
        hostId = "67676767";
        useNetworkd = true;
        nat.externalInterface = "enp1s0";
      };

      boot = {
        initrd.availableKernelModules = [
          "ahci"
          "xhci_pci"
          "virtio_pci"
          "usb_storage"
          "sr_mod"
          "virtio_blk"
          "virtio_scsi"
        ];
        kernelModules = [ "kvm-amd" ];

        # fix rpool import failure on qemu
        zfs.devNodes = "/dev";
        zfs.forceImportRoot = false;
      };

      systemd.network = {
        enable = true;
        networks."10-eth" = {
          matchConfig.Name = "enp1s0";
          networkConfig = {
            DHCP = "ipv4";
            IPv6AcceptRA = true;
          };
          linkConfig.RequiredForOnline = "routable";
        };
      };

      services.resolved.settings.Resolve.DNSStubListener = "no";

      modules.gateway.tld = "staging.7sref";
    };
}
