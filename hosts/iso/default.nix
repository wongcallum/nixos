{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (config.flake) keys;

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

            # nixos-anywhere drives the install over SSH as root. The upstream
            # installation-device profile gives root an *empty* password and OpenSSH
            # refuses to authenticate those, so PasswordAuthentication alone can never
            # let anyone in — a key is the only way. On a target with no display (liz
            # loses its iGPU with the Ryzen board) there is also no console on which to
            # run `passwd`, so this has to be baked into the image.
            users.users.root.openssh.authorizedKeys.keys = keys.callum;

            # Publish over mDNS so a headless target is reachable at `nixos.local`
            # instead of having to be found in the router's DHCP leases.
            services.avahi = {
              enable = true;
              nssmdns4 = true;
              publish = {
                enable = true;
                addresses = true;
                workstation = true;
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
