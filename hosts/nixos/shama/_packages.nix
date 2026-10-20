{ inputs, pkgs, ... }:
let
  inherit (inputs.self.packages.${pkgs.stdenv.hostPlatform.system}) openscq30-cli;
  # waproto's generated protobuf code, as one codegen unit, gets rustc
  # OOM-killed inside vm-ci's 10G nix-daemon cgroup
  # workaround: zapfast-waproto-oom
  zapfast = inputs.zapfast.packages.${pkgs.stdenv.hostPlatform.system}.zapfast.overrideAttrs (old: {
    # in Cargo.toml, so the check phase's `cargo test` builds it the same way
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
    coder
    trilium-desktop
    xournalpp
    scrcpy
    (obs-studio.override { browserSupport = false; })
    picard
    equibop
    feishin
    faugus-launcher
    tigervnc
    openscq30-cli
    zapfast
  ];
}
