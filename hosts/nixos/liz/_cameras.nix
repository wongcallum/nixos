# Security cameras. go2rtc on liz holds the DVR credentials and pulls
# each stream once; Frigate in the GPU VM records and detects from that
# restream, and describes events with a VLM on the same GPU.
{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (config.gpuVm) hostAddr guestAddr llamaPort;

  rtspPort = 8554;
  mqttPort = 1883;

  # <channel>01 is the main stream, <channel>02 the 960x576 substream that
  # polygons are measured in.
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

  # Frigate takes fractions, and string-compares each to "1.0" to spot pixels
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

  recordingsDataset = "tank/frigate";
  # Frigate prunes recordings by free space, which the quota bounds.
  recordingsQuota = "300G";

  vlm = "qwen3-vl-4b";

  restream = name: "rtsp://${hostAddr}:${toString rtspPort}/${name}";

  # SQLite over virtiofs hits "database is locked"; the store's disk is local ext4
  dbDir = "/nix/var/lib/frigate";

  frigateSettings = {
    # without it Frigate migrates the config as if from 0.13, mangling genai
    version = "0.18-0";

    database.path = "/db/frigate.db";

    mqtt = {
      enabled = true;
      host = hostAddr;
      port = mqttPort;
    };
    # Caddy terminates TLS in front of the authenticated port
    tls.enabled = false;

    ffmpeg.hwaccel_args = "preset-nvidia";

    # https://docs.frigate.video/configuration/object_detectors
    detectors.onnx.type = "onnx";
    model = {
      model_type = "yolo-generic";
      width = 320;
      height = 320;
      input_tensor = "nchw";
      input_dtype = "float";
      # YOLOv9-s exported by hand with the Dockerfile from the docs above;
      # nothing downloads it, and Frigate won't start without it
      path = "/config/model_cache/yolo.onnx";
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
        objects = [
          "person"
          "car"
        ];
      };
    };
    review = {
      alerts.labels = [ "person" ];
      genai.enabled = true;
    };
    genai.local = {
      provider = "llamacpp";
      base_url = "http://127.0.0.1:${toString llamaPort}";
      model = vlm;
      # a chat model's embeddings make semantic search silently useless
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

    # live view; Frigate maps streams named after the camera
    go2rtc.streams = lib.mapAttrs (name: _: [ (restream name) ]) cameras;

    cameras = lib.mapAttrs (name: camera: {
      zones = lib.mapAttrs (_: polygon: { coordinates = coordinates polygon; }) camera.zones;
      review.alerts =
        if camera.alerts or true && camera.zones != { } then
          { required_zones = lib.attrNames camera.zones; }
        else
          { labels = [ ]; };
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

  guestModule =
    { config, pkgs, ... }:
    let
      dataDir = config.utils.dataDir "frigate";
      configFile = (pkgs.formats.yaml { }).generate "frigate.yml" frigateSettings;
    in
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      hardware.nvidia-container-toolkit.enable = true;
      # the root is a tmpfs; keep images on the store's disk
      virtualisation.containers.storage.settings.storage.graphroot = "/nix/var/lib/containers/storage";

      # Frigate's ONNX detector runs on the GPU only in the upstream image;
      # nixpkgs' frigate with cudaSupport compiles torch and friends locally.
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
            # nvidia.com/gpu=all resolves through the generated CDI spec
            After = [ "nvidia-container-toolkit-cdi-generator.service" ];
          };
          # A writable copy, so the UI's zone and mask editors can save; they
          # last until the next restart unless copied into frigateSettings.
          serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/install -Dm0644 ${configFile} ${dataDir}/config.yml";
        };
      };

      systemd.tmpfiles.rules = [
        "d ${dataDir}/model_cache 0755 root root -"
        "d ${dbDir} 0755 root root -"
      ];

      # 5000 is unauthenticated, for Home Assistant on liz; 8971 for Caddy
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
        # shares the 12 GB card with OCR, translation and the detector
        cache-type-k = "q8_0";
        cache-type-v = "q8_0";
      };
    };
in
{
  sops.secrets."cameras/dvr-env".restartUnits = [ "go2rtc.service" ];

  services.go2rtc = {
    enable = true;
    settings = {
      # the web UI shows source URLs, credentials included
      api.listen = "127.0.0.1:1984";
      # tailscale0 is trusted, so keep the unauthenticated restream on the tap
      rtsp.listen = "${hostAddr}:${toString rtspPort}";
      webrtc.listen = "";

      # DVR_URL is rtsp://user:password@address:554, from the secret
      streams = lib.concatMapAttrs (name: camera: {
        ${name} = "\${DVR_URL}/Streaming/Channels/${toString camera.channel}01";
        "${name}_sub" = "\${DVR_URL}/Streaming/Channels/${toString camera.channel}02";
      }) cameras;
    };
  };

  services.mosquitto = {
    enable = true;
    # Home Assistant connects locally, Frigate over the tap
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
      # binding the tap's address fails until networkd has configured it
      after = [ "sys-subsystem-net-devices-vmtap.device" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
      };
    }))
    {
      go2rtc.serviceConfig.EnvironmentFile = config.sops.secrets."cameras/dvr-env".path;

      frigate-recordings = {
        description = "Provision the Frigate recordings dataset";
        after = [ "zfs-mount.service" ];
        before = [ "gpu-vm-virtiofsd-recordings.service" ];
        requiredBy = [ "gpu-vm-virtiofsd-recordings.service" ];
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

  gpuVm = {
    guestModules = [ guestModule ];
    shares = [
      {
        tag = "recordings";
        source = "/${recordingsDataset}";
        mountPoint = "/media/frigate";
        readOnly = false;
        neededForBoot = false;
      }
    ];
    hostPorts = [
      rtspPort
      mqttPort
    ];
  };

  modules.gateway.services.automation-frigate = {
    name = "Frigate";
    domainName = "frigate";
    addr = "${guestAddr}:8971";
    iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/frigate.png";
    category = "Automation";
  };
}
