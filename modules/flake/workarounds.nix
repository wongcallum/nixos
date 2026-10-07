{ config, lib, ... }:
let
  inherit (lib) mkOption types;

  root = ../..;

  # `# workaround: <id>` comments in .nix and .sh files: { <id> = [ "<file>:<line>" ]; }
  markers = lib.zipAttrs (
    lib.concatMap (
      file:
      lib.concatLists (
        lib.imap1 (
          n: line:
          let
            match = builtins.match ".*# workaround: ([a-z0-9-]+).*" line;
          in
          lib.optional (match != null) {
            ${builtins.head match} = "${lib.removePrefix "./" (lib.path.removePrefix root file)}:${toString n}";
          }
        ) (lib.splitString "\n" (builtins.readFile file))
      )
    ) (lib.fileset.toList (lib.fileset.fileFilter (f: f.hasExt "nix" || f.hasExt "sh") root))
  );
in
{
  options.flake.workarounds = mkOption {
    description = "Local workarounds for upstream problems, defined in modules/workarounds.nix.";
    default = { };
    type = types.attrsOf (
      types.submodule (
        { name, ... }:
        {
          options = {
            upstream = mkOption {
              type = types.str;
              description = "Upstream report or fix, or where to file one.";
            };
            done = mkOption {
              type = types.str;
              description = "When the workaround can be removed.";
            };
            cleanup = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Cleanup beyond deleting the marked code.";
            };
            fixed = mkOption {
              type = types.nullOr types.bool;
              default = null;
              description = "Whether `done` holds for the locked inputs, or null if it must be checked by hand.";
            };
            markers = mkOption {
              type = types.listOf types.str;
              readOnly = true;
              default = markers.${name} or [ ];
              description = "Where the code is marked.";
            };
          };
        }
      )
    );
  };

  config = {
    # Every marker defines its id, so a marker without an entry fails
    # evaluation: "option ... was accessed but has no value defined".
    flake.workarounds = lib.mapAttrs (_: _: { }) markers;

    perSystem =
      { pkgs, ... }:
      {
        # Fails once an input update makes a workaround removable, or when an
        # entry no longer marks any code.
        checks.workarounds =
          let
            problems = lib.concatLists (
              lib.mapAttrsToList (
                id: w:
                lib.optional (w.fixed != null && w.fixed) "${id} can be removed: ${w.done}"
                ++ lib.optional (w.markers == [ ]) "${id} marks no code: remove the entry or restore its marker"
              ) config.flake.workarounds
            );
          in
          pkgs.runCommand "workarounds" { } (
            if problems == [ ] then
              "touch $out"
            else
              ''
                printf '%s' ${lib.escapeShellArg (lib.concatLines problems)} >&2
                exit 1
              ''
          );
      };
  };
}
