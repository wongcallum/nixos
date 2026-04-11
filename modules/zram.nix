{
  flake.modules.nixos.zram = {
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
    };

    # kernel's native OOM killer can sometimes fail to trigger
    systemd.oomd.enable = true;
  };
}
