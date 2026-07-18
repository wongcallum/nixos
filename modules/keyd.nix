{
  flake.modules.nixos.keyd = {
    services.keyd = {
      enable = true;
      keyboards.default = {
        ids = [ "*" ];
        settings.main = {
          capslock = "esc";
          rightshift = "overload(shift, rightshift)";
        };
      };
    };
  };
}
