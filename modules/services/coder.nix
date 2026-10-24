{ config, lib, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.modules.nixos.coder =
    { config, ... }:
    {
      imports = [ nixos.docker ];

      systemd.services.coder.after = [ "postgresql.service" ];

      # Coder's Terraform provisioner is part of the service closure.
      nixpkgs.config.allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) [ "terraform" ];

      services.coder = {
        enable = true;
        listenAddress = "0.0.0.0:3000";
        accessUrl = "https://coder.${config.modules.gateway.tld}";
        wildcardAccessUrl = "*.coder.${config.modules.gateway.tld}";
        database.createLocally = true;
        environment.extra = {
          CODER_TELEMETRY_ENABLE = "false";
          CODER_SESSION_DURATION = "168h";
          CODER_DEFAULT_TOKEN_LIFETIME = "744h";
        };
      };

      users.users.coder.extraGroups = [ "docker" ];
    };

  # coder runs on salt, which liz reaches over tailscale.
  flake.modules.nixos.gateway =
    { config, ... }:
    let
      addr = "${config.modules.hostAddrs.salt}:3000";
    in
    {
      modules.gateway.services.coder = {
        name = "Coder";
        domainName = "coder";
        inherit addr;
        category = "Development";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/coder-light.svg"; # mislabelled, actually for dark
      };
      # Route generated Coder app subdomains to the Coder server.
      modules.gateway.services.coder-apps = {
        name = "Coder workspace apps";
        domainName = "*.coder";
        inherit addr;
        category = "Development";
        hidden = true;
      };
    };
}
