{ inputs, ... }:
{
  flake.modules.nixos.determinate = {
    imports = [ inputs.determinate.nixosModules.default ];

    nix.settings = {
      # evaluate across all available cores
      eval-cores = 0;
      # only copy flakes / trees fetched by builtins.fetchTree into the store
      # when a derivation actually depends on them
      lazy-trees = true;

      # public, anonymous cache serving the Determinate Nix package, so it is
      # substituted rather than compiled from source (cache.flakehub.com itself
      # needs a FlakeHub token; this mirror does not)
      extra-substituters = [ "https://install.determinate.systems" ];
      extra-trusted-public-keys = [
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
        "cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio="
        "cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU="
        "cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU="
        "cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8="
      ];
    };
  };
}
