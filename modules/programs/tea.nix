{
  flake.modules.nixos.tea =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        (pkgs.tea.overrideAttrs (old: {
          # nixpkgs is still on tea 0.14.0 for some reason, which uses a version of urfave/cli which emits broken fish completions
          postConfigure = (old.postConfigure or "") + ''
            chmod +w vendor/github.com/urfave/cli/v3/autocomplete
            sed -i \
              -e 's/%\[1\]/%[1]s/g' \
              -e 's/printf "%s/printf "%%s/g' \
              -e 's/\\t%s/\\t%%s/g' \
              vendor/github.com/urfave/cli/v3/autocomplete/fish_autocomplete
          '';
        }))
      ];
    };
}
