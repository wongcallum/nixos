{ inputs, ... }:
{
  flake.modules.nixos.nix-discord-rpc = {
    imports = [ inputs.nix-discord-rpc.nixosModules.default ];

    services.nix-discord-rpc = {
      enable = true;
      clientId = "1523300804696739900";
    };
  };
}
