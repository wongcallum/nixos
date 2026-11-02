{ inputs, pkgs, ... }:
let
  inherit (inputs.self.packages.${pkgs.stdenv.hostPlatform.system}) openscq30-cli;
  # As one codegen unit, waproto runs rustc out of memory in vm-ci's 10G daemon cgroup.
  # workaround: zapfast-waproto-oom
  zapfast = inputs.zapfast.packages.${pkgs.stdenv.hostPlatform.system}.zapfast.overrideAttrs (old: {
    # In Cargo.toml, so the check phase's `cargo test` builds it the same way.
    postPatch = (old.postPatch or "") + ''
      cat >> Cargo.toml <<EOF

      [profile.release.package.waproto]
      codegen-units = 16
      EOF
    '';
  });
in
{
  imports = with inputs.self.modules.nixos; [
    helium
  ];

  environment.systemPackages = with pkgs; [
    trilium-desktop
    xournalpp
    scrcpy
    (obs-studio.override { browserSupport = false; })
    picard
    tigervnc
    openscq30-cli
    zapfast
    android-tools
    aria2
    ffmpeg
    tsukimi
    t3code-desktop
  ];

  nix.settings = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };
}
