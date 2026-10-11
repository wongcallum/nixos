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

            # default: https://github.com/bilibili/Index-Translate#default-inference-settings
            [*]
            ctx-size = 32768
            temp = 0
            n-predict = 4096
            chat-template-kwargs = {"enable_thinking":false}
            reasoning = off

            # mmproj automatically downloads
            [index-translate-2b]
            hf-repo = IndexTeam/Index-Translate-2B-GGUF:Q8_0
            load-on-startup = true

            [index-translate-9b]
            hf-repo = IndexTeam/Index-Translate-9B-GGUF:Q6_K
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
              models-max = 1;

              n-gpu-layers = 999;
              kv-offload = true;
              flash-attn = "on";
              parallel = 1;
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
