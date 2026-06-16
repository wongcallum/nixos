# Remote GPU desktop on staging: GTX 1060 passthrough + Sunshine/Moonlight.
#
# Why this shape:
#  - niri needs a real GPU EGL (EGL_EXT_device_drm) and a *connected* output; it
#    has no headless/virtual-output support. virtio-gpu can't satisfy this here
#    because the QEMU host has only NVIDIA GPUs, so host EGL for gl=on fails with
#    EGL_NOT_INITIALIZED.
#  - Passing the 1060 through gives niri a real GPU. A forced EDID makes one of
#    its connectors report "connected" with no monitor attached, so niri has an
#    output to render to. Sunshine captures that CRTC via KMS and encodes it with
#    NVENC for Moonlight clients (reach staging over Tailscale).
#
# Host / virt-manager bring-up (do this first):
#  1. Add the GTX 1060 (PCI 04:00.0) as a "PCI Host Device" to the staging VM.
#  2. Set the VM Video model to "None" so the 1060 is the only GPU (niri and
#     Sunshine then use /dev/dri/renderD128 with no extra config). Use the libvirt
#     Serial console / ssh for early-boot visibility.
#  3. Boot, `ssh staging`, and confirm the forced connector is live:
#       for p in /sys/class/drm/card*-*/status; do echo "$p -> $(cat $p)"; done
#     If the "connected" connector is not DP-1, change `outputs.<name>` below to
#     match and rebuild.
{ config, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true; # NVIDIA driver is unfree

  # NVIDIA proprietary driver. The 1060 is Pascal: the open kernel module is
  # Turing+ only, and the current (590+) branch dropped Pascal, so pin the 580
  # legacy branch which is the last to support it.
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    modesetting.enable = true; # nvidia-drm.modeset=1, required for Wayland/niri
    open = false;
    nvidiaSettings = false; # headless box, no settings GUI
  };

  # Forced virtual display so the passed-through GPU has an output with no monitor
  # attached (2560x1440@144, CVT reduced-blanking). The module bakes the EDID into
  # initrd and adds `video=DP-1:e` + `drm.edid_firmware=DP-1:edid/VIRT1440p144.bin`.
  # Both the mode and the edid override are required for the NVIDIA proprietary
  # driver. RB timing (hblank 160) keeps the pixel clock at 604.25 MHz; vtotal 1543
  # gives 604.25e6 / (2720*1543) = 143.97 Hz.
  hardware.display = {
    edid.modelines."VIRT1440p144" = "604.25  2560 2608 2640 2720  1440 1443 1448 1543  -hsync +vsync";
    outputs."DP-1" = {
      edid = "VIRT1440p144.bin";
      mode = "e";
    };
  };

  services = {
    xserver.videoDrivers = [ "nvidia" ];

    # Auto-login straight into niri so a graphical session (and the Sunshine user
    # service) is up at boot without anyone typing into the greeter.
    greetd.settings.initial_session = {
      command = "${pkgs.niri}/bin/niri-session";
      user = "callum";
    };

    # Sunshine: KMS capture + NVENC. Pair from Moonlight via https://staging:47990.
    sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true; # needed for DRM/KMS screen capture
      openFirewall = true;
      # Build with CUDA so Sunshine imports the captured KMS framebuffer straight
      # into NVENC (zero-copy on-GPU). Without it Sunshine logs "NVENC without CUDA
      # support. Reverting back to GPU -> RAM -> GPU" and does a synchronous PCIe
      # readback every frame, which bottlenecks 1440p to ~40fps.
      # cudaSupport also pulls in autoAddDriverRunpath, which bakes the NVIDIA driver
      # lib dir into the binary RUNPATH — needed because capSysAdmin gives the binary
      # file capabilities, so glibc runs it AT_SECURE and ignores LD_LIBRARY_PATH
      # when ffmpeg dlopens libcuda.so.1 / libnvidia-encode.so.1.
      package = pkgs.sunshine.override { cudaSupport = true; };
      settings = {
        capture = "kms";
        encoder = "nvenc";
        adapter_name = "/dev/dri/renderD128";
      };
    };
  };

  # Sunshine injects mouse/keyboard by creating virtual devices via /dev/uinput,
  # which hardware.uinput exposes as root:uinput 0660 (no uaccess tag) — so the
  # user running Sunshine must be in the uinput group. input covers reading the
  # resulting/existing input devices.
  users.users.callum.extraGroups = [
    "input"
    "uinput"
  ];
}
