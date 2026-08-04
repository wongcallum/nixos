# Keep the line-out active when headphones are plugged in.
{
  config,
  pkgs,
  ...
}:
let
  stockMixerPaths = "${config.services.pipewire.package}/share/alsa-card-profile/mixer/paths";

  lineoutMixerPath = pkgs.runCommand "analog-output-lineout.conf" { } ''
    cp ${stockMixerPaths}/analog-output-lineout.conf "$out"
    sed -i \
      -e '/^\[Element Headphone\]$/,/^volume = off$/ s/^/; /' \
      -e '/^\[Element Headphone,1\]$/,/^volume = off$/ s/^/; /' \
      -e '/^\[Element Headphone2\]$/,/^volume = off$/ s/^/; /' \
      "$out"
  '';

  headphonesMixerPath = pkgs.runCommand "analog-output-headphones.conf" { } ''
    cp ${stockMixerPaths}/analog-output-headphones.conf "$out"
    sed -i \
      -e '/^\[Element Front\]$/,/^volume = zero$/ s/^/; /' \
      "$out"
  '';
in
{
  environment.etc = {
    "alsa-card-profile/mixer/paths/analog-output-lineout.conf".source = lineoutMixerPath;
    "alsa-card-profile/mixer/paths/analog-output-headphones.conf".source = headphonesMixerPath;
  };
}
