{
  lib,
  stdenv,
  buildNpmPackage,
  importNpmLock,
  makeWrapper,
  python3,
  nodejs,
  electron,
  hermesSrc,
}:

let
  repoRoot = /. + builtins.unsafeDiscardStringContext (toString hermesSrc);
  rootPackageJson = builtins.fromJSON (builtins.readFile (repoRoot + "/package.json"));
  rootPackageLock = builtins.fromJSON (builtins.readFile (repoRoot + "/package-lock.json"));

  expandWorkspace =
    pattern:
    let
      parts = lib.splitString "/" pattern;
    in
    if lib.last parts == "*" then
      let
        parent = lib.concatStringsSep "/" (lib.init parts);
        entries = builtins.readDir (repoRoot + "/${parent}");
        dirs = lib.filterAttrs (_: t: t == "directory") entries;
      in
      map (d: "${parent}/${d}") (builtins.attrNames dirs)
    else
      [ pattern ];

  workspaceMemberDirs = builtins.filter (d: builtins.pathExists (repoRoot + "/${d}/package.json")) (
    lib.concatMap expandWorkspace rootPackageJson.workspaces
  );

  npmWorkspaceFiles = lib.fileset.unions (
    [
      (repoRoot + "/package.json")
      (repoRoot + "/package-lock.json")
    ]
    ++ map (d: repoRoot + "/${d}/package.json") workspaceMemberDirs
  );

  src = lib.fileset.toSource {
    root = repoRoot;
    fileset = lib.fileset.unions [
      npmWorkspaceFiles
      (repoRoot + "/apps/desktop")
      (repoRoot + "/apps/shared")
      (repoRoot + "/tests/fixtures/session-resume-active-turn.json")
      (repoRoot + "/hermes_cli/linux_desktop_entry.py")
    ];
  };

  packageJson = builtins.fromJSON (builtins.readFile (repoRoot + "/apps/desktop/package.json"));

  targetPlatform =
    if stdenv.hostPlatform.isLinux then
      "linux"
    else
      throw "hermes-desktop: unsupported host platform for node-pty staging";

  targetArch =
    if stdenv.hostPlatform.isx86_64 then
      "x64"
    else
      throw "hermes-desktop: unsupported host arch for node-pty staging";

  renderer = buildNpmPackage {
    pname = "hermes-desktop-renderer";
    inherit (packageJson) version;
    inherit src;

    npmDeps = importNpmLock {
      npmRoot = src;
      package = rootPackageJson;
      packageLock = rootPackageLock;
    };
    inherit (importNpmLock) npmConfigHook;

    dontNpmBuild = true;
    npmRebuildFlags = [ "--ignore-scripts" ];
    ELECTRON_SKIP_BINARY_DOWNLOAD = 1;

    doCheck = true;

    buildPhase = ''
      runHook preBuild

      mkdir -p apps/desktop/build

      patchShebangs .

      pushd apps/desktop
        npm exec -- tsc -b
        npm exec -- vite build

        node scripts/bundle-electron-main.mjs

        ${nodejs}/lib/node_modules/npm/bin/node-gyp-bin/node-gyp rebuild \
          --directory=../../node_modules/node-pty \
          --build-from-source \
          --runtime=electron \
          --target=${electron.version} \
          --nodedir=${electron.passthru.headers} \
          --disturl="" \
          --offline

        node scripts/stage-native-deps.mjs ${targetPlatform} ${targetArch}
      popd

      runHook postBuild
    '';

    checkPhase = ''
      runHook preCheck

      pushd apps/desktop
        npm run postbuild

        STAGED_PTY_NODE="./dist/node_modules/node-pty/build/Release/pty.node"

        if [ ! -f "$STAGED_PTY_NODE" ]; then
          echo "FATAL: Missing staged node-pty native binary at $STAGED_PTY_NODE"
          echo "node-pty must be compiled natively"
          exit 1
        fi
      popd

      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -rn apps/desktop/dist $out/

      echo '{"schemaVersion":1,"commit":"nix-dummy-commit","branch":"nix","dirty":false,"source":"nix"}' > $out/install-stamp.json

      cp -n apps/desktop/package.json $out/
      runHook postInstall
    '';
  };

  connectionJson = builtins.toFile "hermes-desktop-connection.json" ''
    {
      "mode": "remote",
      "remote": {
        "url": "https://hermes.7sref",
        "authMode": "oauth"
      }
    }
  '';
in
stdenv.mkDerivation {
  pname = "hermes-desktop";
  inherit (renderer) version;

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [
    makeWrapper
    python3
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/hermes-desktop $out/bin
    cp -r ${renderer}/* $out/share/hermes-desktop/

    substituteInPlace $out/share/hermes-desktop/dist/electron-main.mjs \
      --replace-fail "process.resourcesPath" "'$out/share/hermes-desktop'"

    cat > $out/bin/hermes-desktop <<EOF
    #!/bin/sh
    set -eu
    : "\''${XDG_CONFIG_HOME:=\$HOME/.config}"
    user_data="\''${HERMES_DESKTOP_USER_DATA_DIR:-\$XDG_CONFIG_HOME/hermes}"
    conn="\$user_data/connection.json"
    if [ ! -e "\$conn" ]; then
      mkdir -p "\$user_data"
      cp ${connectionJson} "\$conn"
    fi
    export HERMES_DESKTOP_USER_DATA_DIR="\$user_data"
    export ELECTRON_IS_DEV=0
    exec ${electron}/bin/electron "$out/share/hermes-desktop" "\$@"
    EOF
    chmod +x $out/bin/hermes-desktop

    # XDG launcher entry + icon (same renderer as upstream)
    mkdir -p $out/share/applications $out/share/icons/hicolor/1024x1024/apps
    install -m 0644 ${src}/apps/desktop/assets/icon.png \
      $out/share/icons/hicolor/1024x1024/apps/hermes.png
    export PYTHONPATH=$(mktemp -d)
    cp ${src}/hermes_cli/linux_desktop_entry.py "$PYTHONPATH/linux_desktop_entry.py"
    export DESKTOP_EXEC="$out/bin/hermes-desktop"
    export DESKTOP_ICON="$out/share/icons/hicolor/1024x1024/apps/hermes.png"
    python3 -c 'import os; from linux_desktop_entry import render_desktop_entry; print(render_desktop_entry(os.environ["DESKTOP_EXEC"], os.environ["DESKTOP_ICON"]))' > $out/share/applications/hermes.desktop
    runHook postInstall
  '';

  meta = {
    description = "Hermes Desktop Backendless";
    homepage = "https://github.com/NousResearch/hermes-agent";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "hermes-desktop";
  };
}
