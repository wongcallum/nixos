{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (config.flake) keys;
  inherit (config.flake.modules) nixos;

  # **Optional**
  # TS_AUTHKEY=tskey-auth-... nix build --impure .#nixosConfigurations.minimal-iso.config.system.build.isoImage
  tsAuthKey = builtins.getEnv "TS_AUTHKEY";
  withTailscale = tsAuthKey != "";

  tailscaleInstaller =
    { pkgs, ... }:
    {
      assertions = [
        {
          assertion = lib.hasPrefix "tskey-" tsAuthKey;
          message = "TS_AUTHKEY is set but does not look like a tailscale auth key (expected a `tskey-` prefix).";
        }
      ];

      services.tailscale = {
        enable = true;
        authKeyFile = pkgs.writeText "installer-tailscale-authkey" tsAuthKey;
        authKeyParameters.ephemeral = true;
        extraDaemonFlags = [ "--state=mem:" ];
        extraUpFlags = [ "--hostname=nixos-installer" ];
      };
    };

  mkIso =
    nixpkgs: isoPath:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/${isoPath}.nix"

        nixos.base
        nixos.global

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

            users.users.root.openssh.authorizedKeys.keys = keys.callum;

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
      ]
      ++ lib.optional withTailscale tailscaleInstaller;
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
