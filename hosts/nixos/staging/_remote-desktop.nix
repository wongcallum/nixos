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
let
  # Detailed timings to advertise, as reduced-blanking XFree86 modelines (clock
  # hdisp hss hse htotal  vdisp vss vse vtotal  flags), *preferred first*. 1080p is
  # plain `cvt -r`; the rest are hand-tuned. 2772 has a non-/8 width cvt won't
  # emit. 2880x1800@120 at cvt's blanking needs 695 MHz, over the EDID DTD 16-bit
  # pixel-clock ceiling of 655.35 MHz, so its blanking is tightened (hblank 80,
  # vblank 40) to land at 653.57 MHz — right under the ceiling, and above the
  # 604.25 MHz of the proven 2560x1440@144 preferred mode, so it only lights up if
  # the GPU accepts the higher clock (else the driver drops it, wrapper falls back).
  edidModelines = [
    "604.25  2560 2608 2640 2720  1440 1443 1448 1543  -hsync +vsync" # 2560x1440@144 (preferred)
    "285.25  1920 1968 2000 2080  1080 1083 1088 1144  +hsync -vsync" # 1920x1080@120
    "653.57  2880 2888 2920 2960  1800 1803 1811 1840  +hsync -vsync" # 2880x1800@120 (reduced blanking)
    "476.74  2772 2820 2852 2932  1280 1283 1293 1355  +hsync -vsync" # 2772x1280@120
  ];

  # The NVIDIA driver only accepts modes present in a *single* forced EDID. Take a
  # valid base block (header/vendor/params/chromaticity) from edid-generator, then
  # overwrite its four descriptor slots with detailed timings encoded straight
  # from the modelines above (edid-generator itself rejects 2772x1280's non-standard
  # aspect ratio), clear the established/standard timing lists so only our four
  # modes are advertised, and fix the checksum.
  baseEdid = pkgs.edid-generator.overrideAttrs {
    clean = true;
    modelines = ''Modeline "base" ${builtins.head edidModelines}'';
  };

  edidMergeScript = pkgs.writeText "edid-merge.py" ''
    import sys, pathlib


    def encode_dtd(ml):
        p = ml.split()
        clock = float(p[0])
        hdisp, hss, hse, htotal = (int(p[i]) for i in (1, 2, 3, 4))
        vdisp, vss, vse, vtotal = (int(p[i]) for i in (5, 6, 7, 8))
        flags = p[9:]
        hpol = 1 if "+hsync" in flags else 0
        vpol = 1 if "+vsync" in flags else 0

        pixclk = round(clock * 100)  # 10 kHz units
        assert pixclk <= 0xFFFF, f"pixel clock {clock} MHz exceeds EDID DTD limit (655.35 MHz)"
        hblank, vblank = htotal - hdisp, vtotal - vdisp
        hso, hpw = hss - hdisp, hse - hss
        vso, vpw = vss - vdisp, vse - vss
        hmm, vmm = 660, 370  # fixed physical size keeps niri scale 1 for every mode

        d = bytearray(18)
        d[0] = pixclk & 0xFF
        d[1] = (pixclk >> 8) & 0xFF
        d[2] = hdisp & 0xFF
        d[3] = hblank & 0xFF
        d[4] = ((hdisp >> 8) << 4) | ((hblank >> 8) & 0x0F)
        d[5] = vdisp & 0xFF
        d[6] = vblank & 0xFF
        d[7] = ((vdisp >> 8) << 4) | ((vblank >> 8) & 0x0F)
        d[8] = hso & 0xFF
        d[9] = hpw & 0xFF
        d[10] = ((vso & 0x0F) << 4) | (vpw & 0x0F)
        d[11] = ((hso >> 8) << 6) | ((hpw >> 8) << 4) | ((vso >> 4) << 2) | (vpw >> 4)
        d[12] = hmm & 0xFF
        d[13] = vmm & 0xFF
        d[14] = ((hmm >> 8) << 4) | ((vmm >> 8) & 0x0F)
        d[17] = 0x18 | (vpol << 2) | (hpol << 1)  # digital separate sync + polarity
        return d


    out, base_path, *modelines = sys.argv[1:]
    base = bytearray(pathlib.Path(base_path).read_bytes()[:128])

    # advertise only our detailed timings: clear established + standard timings
    base[35] = base[36] = base[37] = 0
    for i in range(38, 54):
        base[i] = 1

    for slot, ml in enumerate(modelines):
        off = 54 + slot * 18
        base[off:off + 18] = encode_dtd(ml)

    base[126] = 0  # no extension blocks
    base[127] = (256 - sum(base[:127]) % 256) % 256  # block checksum
    pathlib.Path(out).write_bytes(bytes(base))
  '';

  multiModeEdid =
    pkgs.runCommand "virt-multimode-edid"
      {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.edid-decode
        ];
      }
      ''
        dst="$out/lib/firmware/edid"
        mkdir -p "$dst"
        python3 ${edidMergeScript} "$dst/VIRTMULTI.bin" \
          ${baseEdid}/lib/firmware/edid/base.bin \
          ${lib.concatMapStringsSep " " lib.escapeShellArg edidModelines}
        echo "=== merged EDID ==="
        edid-decode "$dst/VIRTMULTI.bin" || true
      '';

  # Match the streamed display to the Moonlight client's resolution. Sunshine
  # runs prep commands with the client geometry in the environment
  # (SUNSHINE_CLIENT_{WIDTH,HEIGHT,FPS}) but not via a shell, so this wrapper
  # reads those variables directly. The NVIDIA driver rejects any mode not in the
  # forced EDID (a runtime custom mode fails the DRM atomic test), so snap the
  # request to the nearest advertised mode and select it with plain `mode`. On
  # stream end the `reset` path returns to the EDID's preferred mode (`mode auto`).
  matchResolution = pkgs.writeShellApplication {
    name = "sunshine-match-resolution";
    runtimeInputs = with pkgs; [
      niri
      jq
      coreutils
    ];
    text = ''
      output="DP-1"

      if [ "''${1:-}" = "reset" ]; then
        exec niri msg output "$output" mode auto
      fi

      if [ -z "''${SUNSHINE_CLIENT_WIDTH:-}" ] || [ -z "''${SUNSHINE_CLIENT_HEIGHT:-}" ] || [ -z "''${SUNSHINE_CLIENT_FPS:-}" ]; then
        echo "sunshine-match-resolution: no client geometry reported, keeping native mode" >&2
        exit 0
      fi

      # Nearest advertised mode: by pixel-area first, then by refresh to the fps.
      mode=$(niri msg --json outputs | jq -r \
        --arg out "$output" \
        --argjson cw "''${SUNSHINE_CLIENT_WIDTH}" \
        --argjson ch "''${SUNSHINE_CLIENT_HEIGHT}" \
        --argjson cf "''${SUNSHINE_CLIENT_FPS}" '
          .[$out].modes
          | sort_by(
              ( ((.width * .height) - ($cw * $ch)) | (. * .) ),
              ( ((.refresh_rate / 1000) - $cf) | (. * .) )
            )
          | .[0] | "\(.width)x\(.height)@\(.refresh_rate / 1000)"')

      if [ -z "$mode" ] || [ "$mode" = "null" ]; then
        echo "sunshine-match-resolution: no advertised modes for $output" >&2
        exit 0
      fi

      niri msg output "$output" mode "$mode"

      # Let the DRM modeset settle before Sunshine initialises KMS capture,
      # otherwise capture can latch onto the pre-switch resolution.
      sleep 1
    '';
  };
in
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
  # attached. The NVIDIA proprietary driver validates every modeset against the
  # connector's EDID (runtime custom modes fail the DRM atomic test), so the set
  # of streamable resolutions is baked into `multiModeEdid`: four detailed timings
  # (2560x1440@144 [preferred/boot], 1920x1080@120, 2880x1800@120, 2772x1280@120)
  # that the wrapper above switches between per client. The module bakes the EDID
  # into initrd and adds `video=DP-1:e` +
  # `drm.edid_firmware=DP-1:edid/VIRTMULTI.bin` (both required for NVIDIA).
  hardware.display = {
    edid.packages = [ multiModeEdid ];
    outputs."DP-1" = {
      edid = "VIRTMULTI.bin";
      mode = "e";
    };
  };

  # Kill the EFI/firmware "simple-framebuffer" so the passed-through 1060 is the
  # only DRM device. OVMF's GOP framebuffer makes the kernel bind simpledrm as
  # card0 ~0.5s into boot — long before nvidia-drm loads as card1. niri (started
  # by greetd auto-login) then selects card0 as its primary GPU, and once
  # nvidia's aperture handoff tears simpledrm down, niri is wedged forever on the
  # dead node ("error creating renderer for primary GPU: NoDevice card0") with no
  # output for Sunshine to capture ("Unable to find display or encoder").
  # Blacklisting sysfb_init stops the firmware-fb device from ever being created,
  # so the nvidia card is the only DRM card and niri cannot pick the wrong one.
  #
  # Headless box: with no firmware framebuffer there is no local console at all
  # until nvidia-drm loads, so route the kernel console to the virtio console for
  # early-boot visibility. The libvirt domain (nixos-25.11) wires a
  # <console type='virtio'> → guest /dev/hvc0 and has no isa-serial device, so
  # console=ttyS0 would go nowhere; use hvc0. tty0 stays for once the nvidia fb is
  # up. `virsh console nixos-25.11` then shows the whole boot.
  boot.kernelParams = [
    "initcall_blacklist=sysfb_init"
    "console=tty0"
    "console=hvc0"
  ];

  services = {
    xserver.videoDrivers = [ "nvidia" ];

    # Headless streaming box: auto-login straight into niri as callum so a
    # graphical session (and the Sunshine user service) is always up — there is
    # nobody to type into a greeter. initial_session (first boot) and
    # default_session (every start after) point at the same session, so greetd
    # never shows a greeter and respawns niri if it ever exits. This is for
    # staging only; shama keeps the shared desktop module's tuigreet for
    # interactive login. The desktop base already enables greetd, so just
    # override its tuigreet default_session with the niri auto-login session.
    greetd.settings =
      let
        niriSession = {
          command = "${pkgs.niri}/bin/niri-session";
          user = "callum";
        };
      in
      {
        initial_session = niriSession;
        default_session = lib.mkForce niriSession;
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
        # Run before/after every stream to size the niri output to the client.
        # keyValue renders this string verbatim; Sunshine wants a JSON array.
        # elevated=false so `niri msg` runs as callum (owns the niri socket).
        global_prep_cmd = builtins.toJSON [
          {
            do = lib.getExe matchResolution;
            undo = "${lib.getExe matchResolution} reset";
            elevated = "false";
          }
        ];
      };
    };
  };

  # greetd's auto-login (initial_session) fires ~0.5s into boot, before
  # nvidia-drm has registered the passed-through 1060's DRM device. niri has no
  # GPU retry: it panics ("couldn't find a GPU") and exits, so greetd falls back
  # to the greeter and the Sunshine user service has no session to capture. Gate
  # greetd on the GPU being ready by waiting for the nvidia render node. (Don't
  # wait for card0: with the firmware framebuffer disabled above the nvidia card
  # may enumerate as card1, and the old card0 wait was actually satisfied by
  # simpledrm. simpledrm never created a render node, so renderD128 appears only
  # once nvidia-drm is up — a card-number-independent "GPU ready" signal.)
  systemd.services = {
    wait-for-gpu = {
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = 30; # never block the login manager indefinitely
      };
      script = "until [ -e /dev/dri/renderD128 ]; do sleep 0.2; done";
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

  # Sunshine keeps its pairing state (sunshine_state.json), the TLS cert/key it
  # generates on first run, and the web-UI credentials under ~/.config/sunshine.
  # staging rolls back to rpool/nixos/root@blank on every boot and has no /home
  # dataset, so without persisting this every reboot wipes the pairing and every
  # Moonlight client has to re-pair (and the web UI asks to set a new password).
  # Persist just this directory — dotfiles are otherwise intentionally rebuilt
  # from scratch (see _disko.nix).
  environment.persistence.${config.modules.persistence.persistDir}.users.callum.directories = [
    ".config/sunshine"
  ];
}
