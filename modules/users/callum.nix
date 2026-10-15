{
  self,
  config,
  lib,
  ...
}:
let
  inherit (config.flake) keys;
in
{
  flake.modules = lib.mkMerge [
    (self.factory.user "callum" true true)
    {
      nixos.callum =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          users.users.callum = {
            initialPassword = "changeme";
            openssh.authorizedKeys.keys = keys.callum;
            extraGroups = lib.mkMerge [
              (lib.optionals config.virtualisation.libvirtd.enable [ "libvirtd" ])
              (lib.optionals config.virtualisation.docker.enable [ "docker" ])
            ];
          };
          programs.fish.enable = true;
          # you're welcome, claude
          programs.bash.interactiveShellInit = ''
            if [[ $USER == callum && $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]; then
              shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
              exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
            fi
          '';
        };
    }
  ];
}
