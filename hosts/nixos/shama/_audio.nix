{ config, pkgs, ... }:
let
  inherit (config.boot.kernelPackages) kernel;

  # workaround: shama-audio-patches
  # Rebuilds only the two patched modules against the cached kernel; depmod
  # prefers updates/ over the in-tree copies.
  hdaModules = kernel.stdenv.mkDerivation {
    pname = "hda-omnibook7-8e3b";
    inherit (kernel) version src;

    patches = [
      (pkgs.fetchpatch {
        name = "cs35l41-omnibook7-8e3b";
        url = "https://lore.kernel.org/linux-sound/0108019f32ada4d0-8ff2c576-8eb9-4ac4-803e-8ff4e1ce57d3-000000@ap-southeast-2.amazonses.com/raw";
        hash = "sha256-oN9tNA0jeRLel1Rv8gjjNc7iLTBTaYxTZ8ibRhuEjCI=";
      })
      # Rebased onto 7.3:
      # https://lore.kernel.org/linux-sound/0108019f32adb483-2c606373-6a9f-483c-ba13-c413bc432170-000000@ap-southeast-2.amazonses.com/
      ../../../patches/alc245-omnibook7-8e3b.patch
    ];

    nativeBuildInputs = kernel.moduleBuildDependencies;
    hardeningDisable = [ "all" ];

    dirs = [
      "sound/hda/codecs/realtek"
      "sound/hda/codecs/side-codecs"
    ];

    buildPhase = ''
      runHook preBuild
      for d in $dirs; do
        make -j$NIX_BUILD_CORES ${toString kernel.commonMakeFlags} \
          -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
          M=$PWD/$d modules
      done
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      dest=$out/lib/modules/${kernel.modDirVersion}/updates
      install -Dm444 -t $dest \
        sound/hda/codecs/realtek/snd-hda-codec-alc269.ko \
        sound/hda/codecs/side-codecs/snd-hda-scodec-cs35l41.ko
      runHook postInstall
    '';
  };
in
{
  boot.extraModulePackages = [ hdaModules ];
}
