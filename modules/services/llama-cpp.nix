{
  flake.modules.nixos =
    let
      port = 9931;
    in
    {
      llama-cpp =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          # https://huggingface.co/blog/ggml-org/model-management-in-llamacpp
          modelsPreset = pkgs.writeText "llama-cpp-models.ini" ''
            version = 1

            [ling-3.0-tiny]
            hf-repo = bartowski/Ling-3.0-tiny-GGUF:Q6_K_L
            ctx-size = 131072
            load-on-startup = true

            [hy-mt2-1.8b]
            hf-repo = tencent/Hy-MT2-1.8B-GGUF:Q8_0
            ctx-size = 131072

            [lfm2.5-2.6b]
            hf-repo = LiquidAI/LFM2.5-2.6B-GGUF:F16
            spec-draft-hf = LiquidAI/LFM2.5-2.6B-DSpark-GGUF:F16
            spec-type = draft-dspark
            spec-draft-n-max = 10
            spec-draft-n-min = 0
            ctx-size = 131072

            # mmproj automatically downloads
            [unlimited-ocr]
            hf-repo = sahilchachra/Unlimited-OCR-GGUF:BF16
            ctx-size = 8192
            # deterministic output recommended for OCR
            temp = 0
          '';
        in
        {
          services.llama-cpp = {
            enable = true;
            package = (pkgs.llama-cpp.override { cudaSupport = true; }).overrideAttrs {
              # drop once nixpkgs bumps past b10472
              version = "10472";
              src = pkgs.fetchFromGitHub {
                owner = "ggml-org";
                repo = "llama.cpp";
                tag = "b10472";
                hash = "sha256-re0WlafJUDZOPNfIq2ECRSctdrDFVc0fXb5iSd7gDR8=";
                leaveDotGit = true;
                postFetch = ''
                  git -C "$out" rev-parse --short HEAD > $out/COMMIT
                  find "$out" -name .git -print0 | xargs -0 rm -rf
                '';
              };
            };
            settings = {
              inherit port;
              host = "0.0.0.0";

              models-preset = modelsPreset;
              models-max = 1;

              n-gpu-layers = 999;
              kv-offload = true;
              flash-attn = "on";
              parallel = 1;

              temp = 0.6;
              top-p = 0.95;
              top-k = 20;
              min-p = 0.00;
            };
          };

          networking.firewall.allowedTCPPorts = [ port ];

          systemd.services.llama-cpp = lib.mkIf config.services.llama-cpp.enable {
            unitConfig = {
              Wants = [ "systemd-modules-load.service" ];
              After = [ "systemd-modules-load.service" ];
            };

            serviceConfig = {
              ExecStartPre = "${pkgs.bash}/bin/bash -c 'until ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -L >/dev/null 2>&1; do ${pkgs.coreutils}/bin/sleep 1; done'";
              TimeoutStartSec = "infinity";
              DynamicUser = lib.mkForce false;
              User = "root";
              Environment = [ "LLAMA_CACHE=/work/llama-cache" ];
              ReadWritePaths = [ "/work/llama-cache" ];
            };
          };
        };
      gateway = {
        modules.gateway.services.llama-cpp = {
          name = "llama.cpp";
          domainName = "llama";
          iconUrl = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/llama-cpp.svg";
          addr = "10.0.0.4:${toString port}";
          category = "Development";
        };
      };
    };
}
