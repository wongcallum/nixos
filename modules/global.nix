{ lib, ... }:
{
  flake.modules.nixos.global = _: {
    options.modules = {
      gateway.tld = lib.mkOption {
        type = lib.types.str;
        default = "7sref";
        description = "Top-level domain for services";
      };

      ssh.enable = lib.mkEnableOption "OpenSSH";
      tailscale.enable = lib.mkEnableOption "Tailscale";
      fonts.enable = lib.mkEnableOption "fonts";
      samba.enable = lib.mkEnableOption "Samba";
      velocity.enable = lib.mkEnableOption "Velocity proxy";

      users = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.enable = lib.mkEnableOption "user account";
          }
        );
        default = { };
      };

      containers = {
        media-sonarr = lib.mkEnableOption "Sonarr";
        media-radarr = lib.mkEnableOption "Radarr";
        media-prowlarr = lib.mkEnableOption "Prowlarr";
        media-flaresolverr = lib.mkEnableOption "FlareSolverr";
        media-qbittorrent = lib.mkEnableOption "qBittorrent";
        media-jellyfin = lib.mkEnableOption "Jellyfin";

        homeassistant = lib.mkEnableOption "Home Assistant";
        evcc = lib.mkEnableOption "evcc";
        mongo = lib.mkEnableOption "MongoDB";

        forgejo = lib.mkEnableOption "Forgejo";

        ai-searxng = lib.mkEnableOption "SearXNG";
        ai-openwebui = lib.mkEnableOption "Open WebUI";
        ai-copilot-api = lib.mkEnableOption "Copilot API";
        ai-langflow = lib.mkEnableOption "Langflow";
        silverbullet = lib.mkEnableOption "SilverBullet";

        minecraft-server = lib.mkEnableOption "Minecraft Server";

        gallery = lib.mkEnableOption "Gallery";

        immich = lib.mkEnableOption "Immich";

        collabst = lib.mkEnableOption "Collabst";
      };
    };
  };
}
