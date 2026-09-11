{ pkgs, ... }:
{
  services.sunshine = {
    enable = true;
    openFirewall = true;
    package = pkgs.sunshine.override { cudaSupport = true; };
    settings = {
      capture = "x11";
      encoder = "nvenc";
    };
  };

  users.users.callum.extraGroups = [
    "input"
    "uinput"
  ];
}
