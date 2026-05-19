{
  lib,
  stdenvNoCC,
  fetchzip,
}:

let
  fonts = [
    "BmPlus_ToshibaSat_8x16"
    "BmPlus_AST_PremiumExec"
    "Bm437_ToshibaTxL1_8x16"
    "Bm437_DOS-V_re_JPN24"
  ];
in
stdenvNoCC.mkDerivation rec {
  pname = "personal-bitmap-fonts";
  version = "2.2";
  meta.sourceProvenance = [ lib.sourceTypes.binaryBytecode ];

  src = fetchzip {
    stripRoot = false;
    url = "https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v${version}_linux.zip";
    sha256 = "sha256-54U8tZzvivTSOgmGesj9QbIgkSTm9w4quMhsuEc0Xy4=";
  };

  installPhase = ''
    runHook preInstall

    cd "otb - Bm (linux bitmap)"
    install -D -m444 -t $out/share/fonts/misc ${lib.concatMapStringsSep " " (f: f + ".otb") fonts}

    runHook postInstall
  '';
}
