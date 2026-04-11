let
  username = "colin";
in
{
  flake.modules.nixos.${username} = {
    users.users.${username} = {
      isNormalUser = true;
      home = "/home/${username}";
    };
  };
}
