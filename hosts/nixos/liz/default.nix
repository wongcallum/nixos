{
  config,
  inputs,
  microvmLib,
  ...
}:
{
  flake.modules.nixos."hosts/nixos/liz" = {
    imports = [
      # convention: write all host-specific configuration as regular
      # nixos modules instead of flake-parts modules.
      ./_disko.nix
      ./_configuration.nix
      ./_networking.nix

      inputs.disko.nixosModules.default
      inputs.microvm.nixosModules.host
      (microvmLib.mkHostNetworking {
        n = 1;
        hostname = "vm-gallery";
      })
      (microvmLib.mkHostNetworking {
        n = 2;
        hostname = "vm-jenkins";
      })
    ]
    ++ (with config.flake.modules.nixos; [
      uefi
      zram
      impermanence-zfs
      persistence
      sops

      callum
      colin

      ssh
      tailscale
      gateway
      libvirt
      metrics
      monitoring
      samba
      syncthing-server
      qbittorrent

      quadlet-productivity
      quadlet-media
      quadlet-automation
      quadlet-development
      quadlet-immich
      quadlet-collabst
    ]);

    microvm.vms.vm-gallery = {
      flake = inputs.self;
      restartIfChanged = true;
    };

    microvm.vms.vm-jenkins = {
      flake = inputs.self;
      restartIfChanged = true;
    };

    # TODO: find a way to move this somewhere else
    modules.gateway.services.development-jenkins = {
      name = "Jenkins";
      domainName = "jenkins";
      addr = "10.0.0.3:8080";
      iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/jenkins.png";
      category = "Development";
    };
  };
}
