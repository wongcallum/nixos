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
{
  config,
  lib,
  pkgs,
  ...
}:
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

    # Headless streaming box: auto-login straight into niri as callum so a
    # graphical session (and the Sunshine user service) is always up — there is
    # nobody to type into a greeter. initial_session (first boot) and
    # default_session (every start after) point at the same session, so greetd
    # never shows a greeter and respawns niri if it ever exits. This is for
    # staging only; wky keeps the shared desktop module's dms-greeter for
    # interactive login.
    displayManager.dms-greeter.enable = lib.mkForce false;
    # dms-greeter is what enabled greetd; turn it on directly now that it is off.
    greetd.enable = true;
    greetd.settings =
      let
        niriSession = {
          command = "${pkgs.niri}/bin/niri-session";
          user = "callum";
        };
      in
      {
        initial_session = niriSession;
        default_session = niriSession;
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

  # greetd's auto-login (initial_session) fires ~0.5s into boot, before
  # nvidia-drm has registered the passed-through 1060's DRM device. niri has no
  # GPU retry: it panics ("couldn't find a GPU") and exits, so greetd falls back
  # to the greeter and the Sunshine user service has no session to capture. Gate
  # greetd on the card node appearing — niri then starts after the GPU is ready.
  systemd.services = {
    wait-for-gpu = {
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = 30; # never block the login manager indefinitely
      };
      script = "until [ -e /dev/dri/card0 ]; do sleep 0.2; done";
    };

    greetd = {
      wants = [ "wait-for-gpu.service" ];
      after = [ "wait-for-gpu.service" ];
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
