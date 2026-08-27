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
        {
          services.llama-cpp = {
            enable = true;
            package = (pkgs.llama-cpp.override { cudaSupport = true; }).overrideAttrs (old: {
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
            });
            settings = {
              inherit port;
              host = "0.0.0.0";

              # https://huggingface.co/bartowski/Ling-3.0-tiny-GGUF
              hf-repo = "bartowski/Ling-3.0-tiny-GGUF:Q6_K_L";
              alias = "ling-3.0-tiny";

              n-gpu-layers = 999;
              kv-offload = true;
              flash-attn = "on";
              ctx-size = 32768;
              parallel = 1;

              temp = 0.6;
              top-p = 0.95;
              top-k = 20;
              min-p = 0.00;
            };
          };

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
          addr = "10.0.0.4:${port}";
          category = "Development";
        };
      };
    };
}
