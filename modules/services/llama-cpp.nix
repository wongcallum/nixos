{
  flake.modules.nixos.llama-cpp =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      services.llama-cpp = {
        enable = true;
        package = pkgs.llama-cpp.override { cudaSupport = true; };
        settings = {
          host = "127.0.0.1";
          port = 8080;

          hf-repo = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q6_K_XL";
          alias = "qwen3.6-35b-a3b";

          n-cpu-moe = 37;
          n-gpu-layers = 99;
          kv-offload = true;
          threads = 12;
          threads-batch = 12;
          ctx-size = 262144;
          flash-attn = "on";
          cache-type-k = "q8_0";
          cache-type-v = "q8_0";
          spec-draft-type-k = "q8_0";
          spec-draft-type-v = "q8_0";
          parallel = 1;

          # https://unsloth.ai/docs/models/qwen3.6#llama.cpp-mtp-guide
          temp = 0.6;
          top-p = 0.95;
          top-k = 20;
          min-p = 0.00;
          spec-type = "draft-mtp";
          spec-draft-n-max = 2;
        };
      };

      systemd.services.llama-cpp.unitConfig = {
        Wants = [ "systemd-modules-load.service" ];
        After = [ "systemd-modules-load.service" ];
      };

      systemd.services.llama-cpp.serviceConfig = {
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'until ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -L >/dev/null 2>&1; do ${pkgs.coreutils}/bin/sleep 1; done'";
        Environment = lib.mkForce [
          "CUDA_VISIBLE_DEVICES=GPU-41a667ec-3e58-e64c-1eeb-fb916f0b286f"
          "LLAMA_CACHE=/var/lib/llama-cpp/cache"
        ];
        TimeoutStartSec = "infinity";
      };
    };
}
