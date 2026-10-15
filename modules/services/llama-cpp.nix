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

            # no load-on-startup because it would also apply to cached models
            [*]
            ctx-size = 8192
            cache-ram = 0

            # default: https://github.com/bilibili/Index-Translate#default-inference-settings
            # mmproj automatically downloads
            [index-translate-2b]
            hf-repo = IndexTeam/Index-Translate-2B-GGUF:Q8_0
            load-on-startup = true
            ctx-size = 32768
            temp = 0
            n-predict = 4096
            chat-template-kwargs = {"enable_thinking":false}
            reasoning = off
            # paragraphs share the instruction prefix
            cache-ram = 512

            [granite-speech-4.1-2b]
            hf-repo = ibm-granite/granite-speech-4.1-2b-GGUF:Q8_0
            load-on-startup = true
            # trained context per its config and GGUF metadata
            ctx-size = 4096
            temp = 0

            # queries need an "Instruct: ...\nQuery: " prefix; documents don't
            [harrier-oss-v1-0.6b]
            hf-repo = mradermacher/harrier-oss-v1-0.6b-GGUF:Q8_0
            load-on-startup = true
            embedding = true
            pooling = last
            # inputs must fit in one ubatch; compute buffers grow with it
            # (8192 needed ~5 GiB), so cap inputs at 1024 tokens
            ctx-size = 4096
            batch-size = 1024
            ubatch-size = 1024

            [qwen3-reranker-0.6b]
            hf-repo = ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF:Q8_0
            load-on-startup = true
            reranking = true
            ctx-size = 4096
            batch-size = 1024
            ubatch-size = 1024
          '';
        in
        {
          services.llama-cpp = {
            enable = true;
            package = pkgs.llama-cpp.override { cudaSupport = true; };
            settings = {
              inherit port;
              host = "0.0.0.0";

              models-preset = modelsPreset;
              models-max = 4;

              n-gpu-layers = 999;
              kv-offload = true;
              flash-attn = "on";
              # translation clients send one request per paragraph
              parallel = 4;
              # share the full ctx-size across slots instead of splitting it
              kv-unified = true;
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
          addr = "10.0.1.3:${toString port}";
          category = "Development";
        };
      };
    };
}
