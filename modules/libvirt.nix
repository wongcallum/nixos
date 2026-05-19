{
  flake.modules.nixos.libvirt =
    { pkgs, ... }:
    {
      programs.virt-manager.enable = true;

      virtualisation.libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          runAsRoot = true;
          vhostUserPackages = [ pkgs.virtiofsd ];
        };
      };
    };
}
