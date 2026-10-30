{ lib, ... }:
let
  iniAtom = lib.types.oneOf [
    lib.types.bool
    lib.types.int
    lib.types.float
    lib.types.str
  ];

  hfFile = lib.types.submodule {
    options = {
      repo = lib.mkOption {
        type = lib.types.str;
        example = "ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF";
      };
      rev = lib.mkOption {
        type = lib.types.str;
        description = "Commit to download from, so a re-upload can't change the file";
      };
      file = lib.mkOption {
        type = lib.types.str;
        example = "qwen3-reranker-0.6b-q8_0.gguf";
        description = "Path of the file within the repo";
      };
      sha256 = lib.mkOption {
        type = lib.types.str;
        description = "Hex sha256 of the file, which is also its blob name in a Hugging Face cache";
      };
    };
  };
in
{
  # This module sets up llama.cpp in router mode and manages its models declaratively.
  # The models are downloaded to the Nix store before the server starts on demand,
  # so that building the system closure doesn't include the models.
  flake.modules.nixos.llama-cpp =
    { config, pkgs, ... }:
    let
      cfg = config.modules.llama-cpp;
      gcroots = "/nix/var/nix/gcroots/llama-cpp";

      files = lib.unique (
        lib.concatMap (model: lib.filter lib.isAttrs (lib.attrValues model)) (lib.attrValues cfg.models)
      );
      fileName = file: baseNameOf file.file;
      fileUrl = file: "https://huggingface.co/${file.repo}/resolve/${file.rev}/${file.file}";
      storePath =
        file:
        builtins.unsafeDiscardStringContext
          (pkgs.fetchurl {
            name = fileName file;
            url = fileUrl file;
            inherit (file) sha256;
          }).outPath;

      # https://huggingface.co/blog/ggml-org/model-management-in-llamacpp
      modelsPreset = pkgs.writeText "llama-cpp-models.ini" (
        lib.generators.toINIWithGlobalSection { } {
          globalSection.version = 1;
          sections =
            lib.optionalAttrs (cfg.defaults != { }) { "*" = cfg.defaults; }
            // lib.mapAttrs (
              _: lib.mapAttrs (_: value: if lib.isAttrs value then storePath value else value)
            ) cfg.models;
        }
      );

      fetchModels = pkgs.writeShellApplication {
        name = "llama-cpp-fetch-models";
        runtimeInputs = [
          pkgs.coreutils
          config.nix.package
        ];
        text = ''
          # root before downloading so a concurrent GC can't take a fresh file
          rm -rf "${gcroots}.new"
          mkdir -p "${gcroots}.new"
          ${lib.concatMapStrings (file: ''
            ln -s ${lib.escapeShellArg (storePath file)} "${gcroots}.new/"
          '') files}
          rm -rf "${gcroots}"
          mv "${gcroots}.new" "${gcroots}"

          # nix-prefetch-url downloads into TMPDIR first; /tmp may be a tmpfs
          # smaller than a model, so stage on the store's filesystem
          TMPDIR=$(mktemp -d /nix/var/llama-cpp-fetch.XXXXXX)
          export TMPDIR
          trap 'rm -rf "$TMPDIR"' EXIT

          fetch() {
            local name="$1" url="$2" sha256="$3" path="$4"
            nix-store --check-validity "$path" 2>/dev/null && return
            echo "downloading $url"
            fetched=$(nix-prefetch-url --print-path --type sha256 --name "$name" "$url" "$sha256" | tail -n 1)
            if [ "$fetched" != "$path" ]; then
              echo "$url was added as $fetched, expected $path" >&2
              exit 1
            fi
          }
          ${lib.concatMapStrings (file: ''
            fetch ${
              lib.escapeShellArgs [
                (fileName file)
                (fileUrl file)
                file.sha256
                (storePath file)
              ]
            }
          '') files}
        '';
      };
    in
    {
      options.modules.llama-cpp = {
        defaults = lib.mkOption {
          type = lib.types.attrsOf iniAtom;
          default = { };
          description = "Preset settings shared by every model, the `[*]` section";
        };

        models = lib.mkOption {
          type = lib.types.attrsOf (lib.types.attrsOf (lib.types.either iniAtom hfFile));
          default = { };
          example = {
            "qwen3-reranker-0.6b" = {
              model = {
                repo = "ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF";
                rev = "a02f48bb4f057028298c21fa033da2b30d7742d5";
                file = "qwen3-reranker-0.6b-q8_0.gguf";
                sha256 = "22c9979ce4fbcdc5acdc310c6641c32797eff1aa980b8f7a2db8a8ea23429a48";
              };
              reranking = true;
            };
          };
          description = ''
            Model presets by name, written to the models-preset INI.
          '';
        };
      };

      config = {
        assertions = lib.mapAttrsToList (name: model: {
          assertion = !lib.any (lib.hasPrefix "hf-repo") (lib.attrNames model);
          message = "modules.llama-cpp.models.${name}: declare files instead of hf-repo* so they are pinned and garbage collected";
        }) cfg.models;

        services.llama-cpp = {
          enable = true;
          settings.models-preset = modelsPreset;
        };

        systemd.services.llama-cpp = {
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          serviceConfig = {
            # "+" for the nix daemon and gcroots, outside the sandbox
            ExecStartPre = [ "+${lib.getExe fetchModels}" ];
            # first start downloads every model
            TimeoutStartSec = lib.mkDefault "infinity";
          };
        };
      };
    };
}
