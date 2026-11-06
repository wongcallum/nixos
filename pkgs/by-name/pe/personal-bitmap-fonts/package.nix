{
  lib,
  runCommand,
  ultimate-oldschool-pc-font-pack,
}:

let
  fonts = [
    "BmPlus_ToshibaSat_8x16"
    "BmPlus_AST_PremiumExec"
    "Bm437_ToshibaTxL1_8x16"
    "Bm437_DOS-V_re_JPN24"
    "Bm437_IBM_PS-55_re"
  ];
in
runCommand "personal-bitmap-fonts-${ultimate-oldschool-pc-font-pack.version}"
  {
    meta = ultimate-oldschool-pc-font-pack.meta // {
      description = "Selected bitmap fonts from the Ultimate Oldschool PC Font Pack";
    };
  }
  ''
    install -D -m444 -t $out/share/fonts/misc \
      ${lib.concatMapStringsSep " " (
        f: "${ultimate-oldschool-pc-font-pack}/share/fonts/misc/${f}.otb"
      ) fonts}
  ''
