# Local workarounds for upstream problems; see AGENTS.md. Each entry's id
# marks its code as `# workaround: <id>`. `fixed` is evaluated against the
# locked inputs and fails CI when true; entries without it are checked by hand.
{
  config,
  inputs,
  lib,
  ...
}:
let
  # A host's nixpkgs as upstream ships it: no overlays, and not our patched fork.
  pkgsFor =
    host:
    let
      name = config.flake.nixpkgs.${host} or "nixpkgs";
    in
    inputs.${if name == "unstable" then "unstable-upstream" else name}.legacyPackages.x86_64-linux;
in
{
  flake.workarounds = {
    cadvisor-overlay = {
      upstream = "https://github.com/NixOS/nixpkgs/pull/520137";
      done = "liz's and salt's nixpkgs ship cadvisor >= 0.57.0 (liz is on stable, so it may need a backport)";
      fixed = lib.all (host: lib.versionAtLeast (pkgsFor host).cadvisor.version "0.57.0") [
        "liz"
        "salt"
      ];
    };

    dolphin-applications-menu = {
      upstream = "https://github.com/NixOS/nixpkgs/issues/409986";
      done = "the issue is fixed and the fix is in nixpkgs-unstable";
    };

    flux-mcman = {
      upstream = "https://github.com/IogaMaster/flux";
      done = "flux's flake.lock pins deniz-blue/mcman at 2665efb or a later main commit";
      fixed =
        let
          mcman = (lib.importJSON "${inputs.flux}/flake.lock").nodes.mcman.locked;
        in
        # 2665efb's commit date; later commits on main contain it
        mcman.owner == "deniz-blue" && mcman.lastModified >= 1778414270;
    };

    freesmlauncher-java-paths = {
      upstream = "https://github.com/FreesmTeam/FreesmLauncher/pull/233";
      done = "the PR is merged, and the wongcallum/FreesmLauncher multi-modrinth fork is rebased onto it so an empty `jdks` no longer sets FREESMLAUNCHER_JAVA_PATHS";
      cleanup = "keep `override { jdks = [ ]; }`";
      fixed =
        !lib.any (lib.hasPrefix "--prefix FREESMLAUNCHER_JAVA_PATHS")
          (inputs.freesmlauncher.packages.x86_64-linux.freesmlauncher.override { jdks = [ ]; }).qtWrapperArgs;
    };

    kdeconnect-no-bluetooth = {
      upstream = "https://bugs.kde.org/show_bug.cgi?id=513536";
      done = "the bug is fixed and the release with the fix reaches nixpkgs-unstable; 26.08 disabling the Bluetooth backend by default only hides it";
    };

    niri-3fg-drag = {
      upstream = "https://github.com/niri-wm/niri/discussions/2786";
      done = "niri has a native three-finger-drag setting, and enabling it keeps dragging working without the LD_PRELOAD shim";
      cleanup = "delete packages/enable-3fg-drag";
    };

    nix-monitored-completions = {
      upstream = "not filed; open a PR at https://github.com/ners/nix-monitored";
      done = "the locked nix-monitored hands completion requests (NIX_GET_COMPLETIONS) straight to nix";
      cleanup = "delete patches/nix-monitored-completions.patch";
      fixed = lib.hasInfix "NIX_GET_COMPLETIONS" (
        builtins.readFile "${inputs.nix-monitored}/monitored.cc"
      );
    };

    nixbot-eval-options = {
      upstream = "not filed; https://github.com/Mic92/nixbot hard-codes --check-cache-status and leaves EvalSettings.extra_args unset";
      done = "upstream nixbot can pass nix options or extra arguments to nix-eval-jobs, or turn off --check-cache-status";
      cleanup = "delete patches/nixbot-eval-nix-options.patch, import inputs.nixbot.nixosModules.nixbot directly, and move evalNixOptions to the upstream option";
    };

    punktfunk-hevc = {
      upstream = "not filed; git.unom.io/unom/punktfunk, crates/pf-vaapi/src/enc_h265.rs";
      done = "the nix-stable branch's guessed HEVC fallback matches ffmpeg's (CTB and minimum CB sizes, diff_cu_qp_delta_depth)";
      cleanup = "delete patches/punktfunk-hevc-guessed-features.patch";
    };

    shama-audio-patches = {
      upstream = "https://lore.kernel.org/linux-sound/0108019f32ada4d0-8ff2c576-8eb9-4ac4-803e-8ff4e1ce57d3-000000@ap-southeast-2.amazonses.com/ (Cirrus replied that this laptop's _DSD values are wrong, so our settings are too, and plans one patch for all affected laptops)";
      done = "shama's cachyos kernel no longer maps SSID 0x8e3b to \"HP Agusta\"/ALC287_FIXUP_CS35L41_I2C_2 in sound/hda/codecs/realtek/alc269.c, or has a 103C8E3B entry in cs35l41_hda_property.c; prefer Cirrus's values over ours";
      cleanup = "drop the LinuxLatest specialisation's `kernelPatches = mkForce [ ]` too if it's no longer needed";
    };

    vm-ci-nix-2-35 = {
      upstream = "https://github.com/NixOS/nix/commit/6fae3a25f1a07472b45c56862c0ffe2050159e0f (2.35.0), plus https://github.com/NixOS/nix/pull/16220 (2.35.2)";
      done = "vm-ci's nixpkgs defaults to nix >= 2.35.2";
      fixed = lib.versionAtLeast (pkgsFor "vm-ci").nix.version "2.35.2";
    };

    xnviewmp-desktop-entry = {
      upstream = "https://github.com/NixOS/nixpkgs/issues/533948 (buildFHSEnv skips install phases, so appimageTools.wrapType2 drops desktopItems)";
      done = "xnviewmp ships a desktop entry in nixpkgs-unstable, from a package fix or a general fix for the issue";
      cleanup = "remove the commit from scripts/patch-nixpkgs.sh and rerun it; the fork stays";
    };
  };
}
