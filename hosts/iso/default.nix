{
  inputs,
  lib,
  ...
}:
let
  mkIso =
    nixpkgs: isoPath:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/${isoPath}.nix"
        (
          { pkgs, ... }:
          {
            boot.loader.grub.memtest86.enable = true;
            isoImage.makeBiosBootable = true;

            environment.systemPackages = with pkgs; [
              btop
              ripgrep
              neovim
            ];

            environment.variables = {
              EDITOR = "nvim";
              NIXPKGS_ALLOW_UNFREE = "1";
            };

            networking.networkmanager.enable = true;

            programs.nano.enable = false;

            services.openssh = {
              enable = true;
              settings = {
                PasswordAuthentication = true;
              };
            };

            systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];

            nix = {
              package = pkgs.nixVersions.latest;
              settings = {
                experimental-features = [
                  "nix-command"
                  "flakes"
                ];
                substituters = [
                  "https://nix-community.cachix.org"
                ];
                trusted-public-keys = [
                  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                ];
              };
            };
          }
        )
      ];
    };
in
{
  flake.nixosConfigurations = {
    minimal-iso = mkIso inputs.nixpkgs "installation-cd-minimal";
    kde-iso = mkIso inputs.nixpkgs "installation-cd-graphical-calamares-plasma6";
    # minimal-iso-unstable = mkIso inputs.nixpkgs-unstable "installation-cd-minimal";
    # kde-iso-unstable = mkIso inputs.nixpkgs-unstable "installation-cd-graphical-calamares-plasma6";
  };
}
