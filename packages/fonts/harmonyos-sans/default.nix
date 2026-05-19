{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "harmonyos-sans";
  version = "1.0";
  meta.sourceProvenance = [ lib.sourceTypes.binaryBytecode ];

  src = fetchzip {
    stripRoot = false;
    url = "https://communityfile-drcn.op.dbankcloud.cn/FileServer/getFile/cmtyPub/011/111/111/0000000000011111111.20240410094515.88271174201436676532153439068027:50001231000000:2800:867A24FFF367A21762C3F4E121FC473F3CCA7203031BA27AB9AE7A73A5AAAB11.zip#HarmonyOS_Sans.zip";
    sha256 = "sha256-T+Mbo0kQenyRYadOkccrOgNzKlOLTyW/vIGTMz+uNHU=";
  };

  installPhase = ''
    runHook preInstall

    cd "HarmonyOS Sans"
    install -D -m444 -t $out/share/fonts/misc HarmonyOS_Sans*/*.ttf

    runHook postInstall
  '';
}
