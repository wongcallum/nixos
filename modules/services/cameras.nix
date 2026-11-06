{
  inputs,
  lib,
  vmLib,
  ...
}:
let
  inherit (vmLib.vms.vm-gpu) hostAddr guestAddr;

  rtspPort = 8554;
  mqttPort = 1883;

  # Polygons use the 960x576 substream's pixels.
  osdMasks = {
    osd_name = "0,0 105,0 105,20 0,20";
    osd_clock = "690,0 960,0 960,22 690,22";
  };
  cameras = {
    camera_1 = {
      channel = 1;
      zones.zone_1 = "140,195 410,152 665,118 722,118 905,220 884,308 960,350 960,576 360,576 285,445 235,300 165,240";
      motionMasks = osdMasks // {
        foliage = "45,195 205,195 250,300 335,415 335,478 265,482 95,505 35,330";
        street_tree = "540,0 680,0 680,62 540,62";
      };
    };
    camera_2 = {
      channel = 2;
      zones.zone_2 = "543,341 600,352 640,361 830,443 832,455 757,576 425,576 395,543 362,512 515,372";
      motionMasks = osdMasks // {
        street_tree = "105,0 210,0 210,110 60,110 60,20 105,20";
      };
    };
    camera_3 = {
      channel = 3;
      zones.zone_3 = "445,195 615,225 725,250 690,465 640,576 150,576 175,360 260,290 360,230";
      alerts = false;
      motionMasks = osdMasks // {
        street_tree = "525,0 670,0 670,92 525,92";
      };
    };
  };

  otherChannels = lib.genAttrs' (lib.range 4 8) (
    channel: lib.nameValuePair "camera_${toString channel}" channel
  );

  # Frigate takes fractions, and string-compares each to "1.0" to spot pixels.
  fraction =
    pixels: size:
    let
      thousandths = (pixels * 2000 / size + 1) / 2;
    in
    if thousandths >= 1000 then "1" else "0.${lib.fixedWidthNumber 3 thousandths}";
  coordinates =
    polygon:
    lib.concatMapStringsSep "," (
      point:
      let
        xy = map lib.toInt (lib.splitString "," point);
      in
      "${fraction (lib.elemAt xy 0) 960},${fraction (lib.elemAt xy 1) 576}"
    ) (lib.splitString " " polygon);

  # The DVR keeps its own copy.
  recordingsDataset = "scratch/frigate";
  # Frigate prunes recordings by free space, which the quota limits.
  recordingsQuota = "300G";

  vlm = "qwen3-vl-4b";

  # Frigate's documented export. Upstream publishes only PyTorch weights.
  yoloModel =
    let
      # The export runs on the CPU, so it avoids the guest's CUDA torch.
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
      python = pkgs.python3.withPackages (
        ps: with ps; [
          ipython
          matplotlib
          onnx
          onnxruntime
          onnxscript
          onnxslim
          opencv4
          pandas
          pillow
          psutil
          pyyaml
          requests
          scipy
          seaborn
          torch
          torchvision
          tqdm
        ]
      );
      src = pkgs.fetchFromGitHub {
        owner = "WongKinYiu";
        repo = "yolov9";
        rev = "5b1ea9a8b3f0ffe4fe0e203ec6232d788bb3fcff";
        hash = "sha256-DJ2iM+xb00NKaomUcoe7BI/O7mHNu5ARmy/SJYsCEEg=";
      };
      weights = pkgs.fetchurl {
        url = "https://github.com/WongKinYiu/yolov9/releases/download/v0.1/yolov9-s-converted.pt";
        hash = "sha256-Cb+cpK3vN5RPRAZFW1uBtFHB5nMHkW5HAtpozaTT5G0=";
      };
    in
    pkgs.runCommand "yolov9-s-320.onnx" { nativeBuildInputs = [ python ]; } ''
      cp -r ${src} yolov9
      chmod -R u+w yolov9
      cd yolov9
      substituteInPlace models/experimental.py \
        --replace-fail "map_location='cpu')" "map_location='cpu', weights_only=False)"
      # nixpkgs lacks onnx-simplifier, so --simplify gets onnxslim.
      mkdir shim
      printf '%s\n' 'import onnxslim' '__version__ = onnxslim.__version__' \
        'def simplify(m): return onnxslim.slim(m), True' > shim/onnxsim.py
      export PYTHONPATH=$PWD/shim HOME=$TMPDIR MPLCONFIGDIR=$TMPDIR YOLOv5_AUTOINSTALL=false
      cp ${weights} yolov9-s.pt
      python export.py --weights yolov9-s.pt --imgsz 320 --opset 18 --simplify --include onnx
      cp yolov9-s.onnx $out
    '';

  restream = name: "rtsp://${hostAddr}:${toString rtspPort}/${name}";

  # SQLite over virtiofs hits "database is locked". The store's disk is local ext4.
  dbDir = "/nix/var/lib/frigate";
  # TensorRT engines rebuild slowly, and the root is a tmpfs.
  modelCacheDir = "/nix/var/cache/frigate";

  frigateSettings = llamaPort: {
    # Without it, Frigate migrates the config as if from 0.13 and mangles genai.
    version = "0.18-0";

    database.path = "/db/frigate.db";

    mqtt = {
      enabled = true;
      host = hostAddr;
      port = mqttPort;
    };
    tls.enabled = false;

    ffmpeg = {
      hwaccel_args = "preset-nvidia";
      # iOS only plays HEVC tagged hvc1.
      apple_compatibility = true;
    };

    detectors.onnx.type = "onnx";
    model = {
      model_type = "yolo-generic";
      width = 320;
      height = 320;
      input_tensor = "nchw";
      input_dtype = "float";
      path = "/models/yolo.onnx";
      labelmap_path = "/labelmap/coco-80.txt";
    };

    detect.enabled = true;
    objects = {
      track = [
        "person"
        "car"
        "dog"
        "cat"
      ];
      genai = {
        enabled = true;
        objects = [ "person" ];
        prompt = "Describe the {label} in one or two sentences: clothing, anything it carries, and what it does. State only what is visible.";
        use_snapshot = true;
      };
    };
    review = {
      alerts.labels = [ "person" ];
      genai = {
        enabled = true;
        image_source = "recordings";
        # Replaces Frigate's default, threat levels included. The schema forces shortSummary to
        # 70-140 characters, so asking for fewer words makes the model pad.
        activity_context_prompt = ''
          ### Threat levels
          - 0: ordinary activity, including an unknown person who walks in and out in daylight.
          - 1: an unidentified person on the property between 11 PM and 5 AM; trying door or car handles; looking into windows or cars; taking items; climbing fences; loitering with no visible purpose.
          - 2: a weapon or break-in tool, forced entry, violence, or damage or theft in progress.

          ### Writing rules
          - Report only actions visible in the frames. If you can't tell what someone is doing, say where they are and what they hold.
          - Don't guess roles or intent. Don't call anyone a delivery person, visitor or worker, and don't say they are inspecting, checking, attempting or preparing something unless it is plainly visible.
          - Name objects only when clearly visible: a bag is a bag, not a package.
          - Describe what happened, not what didn't: leave out remarks like "no unusual behaviour".
          - No hedging or commentary such as "likely", "appears", "seems", "routine", "consistent with" or "suggesting".
          - title: a short phrase naming the main activity.
          - shortSummary: one complete sentence of 12 to 20 words about the main activity. Leave out the time, date, duration, weather and lighting, and only mention arriving or leaving if that is all the person does.
        '';
      };
    };
    genai.local = {
      provider = "llamacpp";
      base_url = "http://127.0.0.1:${toString llamaPort}";
      model = vlm;
      # A chat model's embeddings make semantic search silently useless.
      roles = [
        "descriptions"
        "chat"
      ];
    };

    record = {
      enabled = true;
      motion.days = 7;
      alerts.retain.days = 30;
      detections.retain.days = 30;
    };
    snapshots = {
      enabled = true;
      retain.default = 30;
    };

    go2rtc.streams = lib.mapAttrs (name: _: [ (restream name) ]) cameras;

    cameras = lib.mapAttrs (name: camera: {
      zones = lib.mapAttrs (_: polygon: { coordinates = coordinates polygon; }) camera.zones;
      review = {
        alerts =
          if camera.alerts or true then
            { required_zones = lib.attrNames camera.zones; }
          else
            { labels = [ ]; };
        detections.required_zones = lib.attrNames camera.zones;
      };
      snapshots.required_zones = lib.attrNames camera.zones;
      motion.mask = lib.mapAttrs (_: polygon: { coordinates = coordinates polygon; }) camera.motionMasks;
      ffmpeg.inputs = [
        {
          path = restream name;
          input_args = "preset-rtsp-restream";
          roles = [ "record" ];
        }
        {
          path = restream "${name}_sub";
          input_args = "preset-rtsp-restream";
          roles = [ "detect" ];
        }
      ];
    }) cameras;
  };
in
{
  flake.modules.nixos = {
    # liz's side: the DVR restream, MQTT and Frigate's recordings dataset.
    cameras =
      { config, utils, ... }:
      {
        security.nix-secrets.secrets."cameras/dvr-env".restartUnits = [ "go2rtc.service" ];

        services.go2rtc = {
          enable = true;
          settings = {
            # The web UI shows source URLs, credentials included.
            api.listen = "127.0.0.1:1984";
            # tailscale0 is trusted, so keep the unauthenticated restream on the tap.
            rtsp.listen = "${hostAddr}:${toString rtspPort}";
            webrtc.listen = "";

            # The secret sets DVR_URL to rtsp://user:password@address:554.
            streams = lib.concatMapAttrs (name: channel: {
              ${name} = "\${DVR_URL}/Streaming/Channels/${toString channel}01";
              "${name}_sub" = "\${DVR_URL}/Streaming/Channels/${toString channel}02";
            }) (lib.mapAttrs (_: camera: camera.channel) cameras // otherChannels);
          };
        };

        services.mosquitto = {
          enable = true;
          listeners =
            map
              (address: {
                inherit address;
                port = mqttPort;
                omitPasswordAuth = true;
                settings.allow_anonymous = true;
                acl = [ "topic readwrite #" ];
              })
              [
                "127.0.0.1"
                hostAddr
              ];
        };

        systemd.services = lib.mkMerge [
          (lib.genAttrs [ "go2rtc" "mosquitto" ] (_: {
            # Binding the tap's address fails until networkd configures it.
            after = [ "sys-subsystem-net-devices-${utils.escapeSystemdPath "vm-gpu"}.device" ];
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = 5;
            };
          }))
          {
            go2rtc.serviceConfig.EnvironmentFile = config.security.nix-secrets.secrets."cameras/dvr-env".path;

            frigate-recordings = {
              description = "Provision the Frigate recordings dataset";
              after = [ "zfs-mount.service" ];
              before = [ "vm-gpu-virtiofsd-recordings.service" ];
              requiredBy = [ "vm-gpu-virtiofsd-recordings.service" ];
              path = [ config.boot.zfs.package ];
              script = ''
                zfs list -H -o name ${recordingsDataset} >/dev/null 2>&1 \
                  || zfs create ${recordingsDataset}
                zfs set quota=${recordingsQuota} ${recordingsDataset}
              '';
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
            };
          }
        ];

        modules.qemuVms.vm-gpu.hostPorts = [
          rtspPort
          mqttPort
        ];

        modules.gateway.services.automation-frigate = {
          name = "Frigate";
          domainName = "frigate";
          addr = "${guestAddr}:8971";
          iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/frigate.png";
          category = "Automation";
        };
      };

    # vm-gpu's side.
    frigate =
      { config, pkgs, ... }:
      let
        dataDir = config.utils.dataDir "frigate";
        configFile = (pkgs.formats.yaml { }).generate "frigate.yml" (
          frigateSettings config.services.llama-cpp.settings.port
        );
      in
      {
        imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

        hardware.nvidia-container-toolkit.enable = true;
        # The root is a tmpfs, so keep images on the store's disk.
        virtualisation.containers.storage.rootful.settings.storage.graphroot =
          "/nix/var/lib/containers/storage";

        # Only the upstream image runs the ONNX detector on the GPU.
        virtualisation.quadlet = {
          autoUpdate.enable = true;

          containers.frigate = config.utils.mkContainer {
            containerConfig = {
              image = "ghcr.io/blakeblackshear/frigate:stable-tensorrt";
              autoUpdate = "registry";
              podmanArgs = [ "--network=host" ];
              devices = [ "nvidia.com/gpu=all" ];
              shmSize = "256m";
              tmpfses = [ "/tmp/cache:size=1g" ];
              volumes = [
                "${dataDir}:/config"
                "${modelCacheDir}:/config/model_cache"
                "${yoloModel}:/models/yolo.onnx:ro"
                "${dbDir}:/db"
                "/media/frigate:/media/frigate"
                "/etc/localtime:/etc/localtime:ro"
              ];
            };
            unitConfig = {
              RequiresMountsFor = [
                dataDir
                "/media/frigate"
              ];
              After = [ "nvidia-container-toolkit-cdi-generator.service" ];
            };
            # A writable copy, so UI edits save until the next restart.
            serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/install -Dm0644 ${configFile} ${dataDir}/config.yml";
          };
        };

        systemd.tmpfiles.rules = [
          "d ${modelCacheDir} 0755 root root -"
          "d ${dbDir} 0755 root root -"
        ];

        # Home Assistant on liz uses the unauthenticated 5000. Caddy uses 8971.
        networking.firewall.allowedTCPPorts = [
          5000
          8971
        ];

        modules.llama-cpp.models.${vlm} = {
          model = {
            repo = "Qwen/Qwen3-VL-4B-Instruct-GGUF";
            rev = "1cd86afb9a95c410a6038ab3b40d8b578c892266";
            file = "Qwen3VL-4B-Instruct-Q4_K_M.gguf";
            sha256 = "66358cb18bb6b3b1b6675aa412c7a88ef01d228f481184d13668e5201c730a0a";
          };
          mmproj = {
            repo = "Qwen/Qwen3-VL-4B-Instruct-GGUF";
            rev = "1cd86afb9a95c410a6038ab3b40d8b578c892266";
            file = "mmproj-Qwen3VL-4B-Instruct-F16.gguf";
            sha256 = "256f3a43bd4205ffef48d6b92715e1e70b5b0e9aef06522584967513a9985331";
          };
          load-on-startup = true;
          # https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct#generation-hyperparameters
          temp = 0.7;
          top-p = 0.8;
          top-k = 20;
          min-p = 0;
          presence-penalty = 1.5;
          # Shares the 12 GB card with OCR, translation and the detector.
          cache-type-k = "q8_0";
          cache-type-v = "q8_0";
        };

        vmGpu.shares = [
          {
            tag = "recordings";
            source = "/${recordingsDataset}";
            mountPoint = "/media/frigate";
            readOnly = false;
            neededForBoot = false;
          }
        ];
      };
  };
}
