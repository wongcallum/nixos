{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixpkgs.acid = "unstable";

  flake.modules.nixos."hosts/nixos/acid" =
    {
      config,
      lib,
      ...
    }:
    {
      imports = [
        # ./_audio-always-on.nix
        ./_disko.nix
        ./_packages.nix

        inputs.disko.nixosModules.default
      ]
      ++ (with nixos; [
        limine
        impermanence-btrfs
        callum
        desktop
        syncthing-desktop
        autofs
        nix-monitored
        freesmlauncher
        libvirt
        docker
      ]);

      system.stateVersion = "26.05";
      system.systemBuilderCommands = "ln -s ${inputs.self.sourceInfo.outPath} $out/src";

      networking.networkmanager.enable = true;
      services = {
        resolved.enable = true;
        xserver.videoDrivers = [ "nvidia" ];
      };

      modules = {
        syncthing-desktop.user = "callum";
        firefox.transparency = {
          enableToolbox = true;
          enablePage = false;
        };
      };

      users.users.callum.extraGroups = [
        "networkmanager"
      ];

      boot = {
        loader.efi.canTouchEfiVariables = true;

        initrd.availableKernelModules = [
          "nvme"
          "xhci_pci"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];
      };

      hardware = {
        enableRedistributableFirmware = true;
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

        graphics.enable = true;

        nvidia = {
          package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
          modesetting.enable = true;
          open = false;
          powerManagement.enable = true;
        };
      };
    };
}
