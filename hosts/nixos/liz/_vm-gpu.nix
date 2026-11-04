{
  config,
  inputs,
  lib,
  microvmLib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.vmGpu;

  stateDir = microvmLib.vmDir "gpu";
  runDir = "/run/vm-gpu";

  inherit (cfg) tap;
  inherit (cfg) hostAddr guestAddr llamaPort;
  guestMac = "02:00:00:00:01:03";

  guestCpus = "3-5 9-11";
  guestVcpus = 6;
  guestMemory = "8G";

  qmpSocket = "${runDir}/qmp.sock";
  shareSocket = tag: "${runDir}/${tag}.sock";

  nixVolume = microvmLib.vmDisk "gpu";
  nixVolumeSizeGiB = 100;
  nixVolumeSize = "${toString nixVolumeSizeGiB}G";
  nixVolumePath = "/dev/zvol/${nixVolume}";
  nixVolumeSerial = "nix";

  shares = [
    {
      tag = "persist";
      source = stateDir;
      mountPoint = "/persist";
      readOnly = false;
      neededForBoot = true;
    }
  ]
  ++ cfg.shares;

  guestModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = with self.modules.nixos; [
        persistence

        callum

        ssh

        metrics

        llama-cpp
      ];

      system.stateVersion = "26.05";
      nixpkgs.config.cudaSupport = true;

      networking = {
        hostName = "vm-gpu";
        useNetworkd = true;
      };

      modules = {
        # The guest has no secrets.
        users.callum.lockPassword = true;
        # The gateway's hostname doesn't resolve here, so use liz's guest port.
        attic.endpoint = "http://${hostAddr}:${toString config.modules.attic.guestPort}/";
      };

      # liz direct-boots the current closure, so older generations can't boot.
      programs.nh.clean.extraArgs = lib.mkForce "--keep 1";

      boot = {
        loader.grub.enable = false;
        initrd.kernelModules = [
          "virtio_pci"
          "virtio_blk"
          "virtiofs"
        ];
        kernelParams = [ "console=ttyS0" ];
      };

      fileSystems = lib.mkMerge [
        {
          "/" = {
            device = "rootfs";
            fsType = "tmpfs";
            options = [
              "size=50%"
              "mode=0755"
            ];
          };

          "/nix" = {
            device = "/dev/disk/by-id/virtio-${nixVolumeSerial}";
            fsType = "ext4";
            options = [ "discard" ];
            neededForBoot = true;
          };
        }
        (lib.listToAttrs (
          map (
            share:
            lib.nameValuePair share.mountPoint {
              device = share.tag;
              fsType = "virtiofs";
              options = [ (if share.readOnly then "ro" else "defaults") ];
              inherit (share) neededForBoot;
            }
          ) shares
        ))
      ];

      hardware = {
        # Links libcuda into /run/opengl-driver for llama.cpp.
        graphics.enable = true;

        nvidia = {
          package = config.boot.kernelPackages.nvidiaPackages.latest;
          modesetting.enable = true;
          open = true;
          nvidiaSettings = false;
        };
      };

      powerManagement.enable = false;

      environment = {
        # Declared so it exists before activation reads it.
        etc."machine-id".text = "8ee14cda66bb46b08992f1945dcf32ad\n";

        systemPackages = [
          pkgs.ffmpeg-full
          pkgs.nvtopPackages.nvidia
        ];
      };

      services = {
        xserver.videoDrivers = [ "nvidia" ];

        llama-cpp = {
          package = pkgs.llama-cpp.override { cudaSupport = true; };
          openFirewall = true;
          settings = {
            port = llamaPort;
            host = "0.0.0.0";

            models-max = 4;

            n-gpu-layers = 999;
            kv-offload = true;
            flash-attn = "on";
            parallel = 4;
            kv-unified = true;
          };
        };
      };

      systemd = {
        network.networks."10-eth" = {
          matchConfig.MACAddress = guestMac;
          address = [ "${guestAddr}/32" ];
          routes = [
            {
              Gateway = hostAddr;
              GatewayOnLink = true;
            }
          ];
          networkConfig = microvmLib.guestDns;
        };

        services.llama-cpp = {
          unitConfig = {
            Wants = [ "systemd-modules-load.service" ];
            After = [ "systemd-modules-load.service" ];
          };

          serviceConfig = {
            ExecStartPre = [
              "${pkgs.bash}/bin/bash -c 'until ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -L >/dev/null 2>&1; do ${pkgs.coreutils}/bin/sleep 1; done'"
            ];
            TimeoutStartSec = "infinity";
          };
        };
      };

      modules.llama-cpp = {
        defaults = {
          ctx-size = 8192;
          cache-ram = 0;
        };

        models = {
          # Defaults from https://github.com/bilibili/Index-Translate#default-inference-settings
          index-translate-2b = {
            model = {
              repo = "IndexTeam/Index-Translate-2B-GGUF";
              rev = "3a0eca6ce931d88d00614d427ab3ed8ff0743902";
              file = "Index-Translate-2B.Q8_0.gguf";
              sha256 = "a09d287f41d297206947a2e51acc29dd03c8b22356111fdb1e289c0c97c173f3";
            };
            load-on-startup = true;
            ctx-size = 32768;
            temp = 0;
            n-predict = 4096;
            chat-template-kwargs = ''{"enable_thinking":false}'';
            reasoning = "off";
            # Paragraphs share the instruction prefix.
            cache-ram = 512;
          };

          # https://huggingface.co/tencent/HunyuanOCR#c-pc-side-deployment-via-llamacpp
          # mmproj stays f16 because quantising the vision encoder hurts small text.
          "hunyuanocr-1.5" = {
            model = {
              repo = "prithivMLmods/HunyuanOCR-1.5-GGUF-Updated";
              rev = "9ddd3b47beb0de305ecd89a717748bac080d7aee";
              file = "HunyuanOCR.Q8_0.gguf";
              sha256 = "675e2bc8d2d85b1fa86bb250e7e44fc1abfc96d0f760b74a6311c5d988c2a2bb";
            };
            mmproj = {
              repo = "prithivMLmods/HunyuanOCR-1.5-GGUF-Updated";
              rev = "9ddd3b47beb0de305ecd89a717748bac080d7aee";
              file = "HunyuanOCR.mmproj-f16.gguf";
              sha256 = "2c9c459f68a9a3c221b1a8088d9c91ac1007ef22aa89045108d14d949f9a3994";
            };
            load-on-startup = true;
            ctx-size = 10240;
            n-predict = 4096;
            # The model card's repetition_penalty covers the whole sequence. The flag
            # rejects -1, so the context size stands in.
            temp = 0;
            repeat-penalty = 1.08;
            repeat-last-n = 10240;
          };
        };
      };
    };

  guest = inputs.unstable.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = lib.recursiveUpdate inputs { inherit inputs; };
    modules = [
      self.modules.nixos.base
      self.modules.nixos.global
      guestModule
    ]
    ++ cfg.guestModules;
  };

  kernel = "${guest.config.boot.kernelPackages.kernel}/${guest.config.system.boot.loader.kernelFile}";
  initrd = "${guest.config.system.build.initialRamdisk}/${guest.config.system.boot.loader.initrdFile}";
  cmdline = toString (
    guest.config.boot.kernelParams
    ++ [
      "init=${guest.config.system.build.toplevel}/init"
    ]
  );

  createVolumes = pkgs.writeShellApplication {
    name = "vm-gpu-volume";
    runtimeInputs = [
      config.boot.zfs.package
      pkgs.e2fsprogs
    ];
    text = ''
      created=false
      if ! zfs list -H -o name "${nixVolume}" >/dev/null 2>&1; then
        zfs create -p -s -V ${nixVolumeSize} \
          -o volblocksize=16K \
          -o compression=lz4 \
          "${nixVolume}"
        created=true
      elif [ "$(zfs get -Hp -o value volsize "${nixVolume}")" -lt ${
        toString (nixVolumeSizeGiB * 1024 * 1024 * 1024)
      } ]; then
        zfs set volsize=${nixVolumeSize} "${nixVolume}"
      fi
      for _ in $(seq 1 50); do
        [ -e "${nixVolumePath}" ] && break
        sleep 0.1
      done
      if [ ! -b "${nixVolumePath}" ]; then
        echo "Missing GPU VM block device: ${nixVolumePath}" >&2
        exit 1
      fi
      if "$created"; then
        mkfs.ext4 "${nixVolumePath}"
      fi
    '';
  };

  # Run this only while QEMU is stopped.
  seedStore = pkgs.writeShellApplication {
    name = "vm-gpu-seed-store";
    runtimeInputs = [ config.nix.package ];
    text = ''
      root="$1"
      system="${guest.config.system.build.toplevel}"
      nix --extra-experimental-features nix-command copy \
        --no-check-sigs --to "$root" "$system"
      nix-env --store "$root" \
        --profile "$root/nix/var/nix/profiles/system" --set "$system"
      mkdir -p "$root/nix/var/nix/gcroots"
      ln -sfn "$system" "$root/nix/var/nix/gcroots/vm-gpu-boot"
    '';
  };

  shareDevices = lib.concatImapStrings (i: share: ''
    -chardev "socket,id=chr-${share.tag},path=${shareSocket share.tag}"
    -device "vhost-user-fs-pci,chardev=chr-${share.tag},tag=${share.tag},addr=0x${toString (i + 5)}"
  '') shares;

  launch = pkgs.writeShellApplication {
    name = "vm-gpu-launch";
    runtimeInputs = [ pkgs.qemu_kvm ];
    text = ''
      # Type=exec marks virtiofsd active before its socket is ready.
      for sock in ${lib.concatMapStringsSep " " (share: shareSocket share.tag) shares}; do
        for _ in $(seq 1 100); do
          [ -S "$sock" ] && break
          sleep 0.1
        done
      done

      args=(
        -name "vm-gpu,process=vm-gpu"
        -machine "q35,accel=kvm,memory-backend=mem"
        -cpu "host,topoext=on"
        -smp "${toString guestVcpus},sockets=1,cores=3,threads=2"
        -m "${guestMemory}"
        # virtiofs needs guest memory in a shareable backend.
        -object "memory-backend-memfd,id=mem,size=${guestMemory},share=on,prealloc=on"
        -nodefaults
        -display none

        -kernel "${kernel}"
        -initrd "${initrd}"
        -append "${cmdline}"

        -chardev "stdio,id=stdio,signal=off"
        -serial "chardev:stdio"

        -device "virtio-rng-pci"

        # Fixed PCI addresses stop devices renumbering by creation order.
        -drive "file=${nixVolumePath},if=none,id=drv-nix,format=raw,cache=none,aio=native,discard=unmap,detect-zeroes=unmap"
        -device "virtio-blk-pci,drive=drv-nix,serial=${nixVolumeSerial},addr=0x3"

        -netdev "tap,id=net0,ifname=${tap},script=no,downscript=no,vhost=on"
        -device "virtio-net-pci,netdev=net0,mac=${guestMac},addr=0x4"

        # As the boot display, the GPU's VBIOS would hang SeaBIOS, so hide its ROM.
        -device "pcie-root-port,id=gpu-port,bus=pcie.0,addr=0x2,chassis=1,multifunction=on"
        -device "vfio-pci,host=0000:08:00.0,bus=gpu-port,addr=0x0.0x0,multifunction=on,rombar=0"
        -device "vfio-pci,host=0000:08:00.1,bus=gpu-port,addr=0x0.0x1,rombar=0"

        # Lets USB devices be hot-attached later.
        -device "qemu-xhci,id=xhci,addr=0x5"

        ${shareDevices}
        -qmp "unix:${qmpSocket},server=on,wait=off"
      )

      exec qemu-system-x86_64 "''${args[@]}"
    '';
  };

  shutdown = pkgs.writeShellApplication {
    name = "vm-gpu-shutdown";
    runtimeInputs = [ pkgs.socat ];
    text = ''
      [ -S "${qmpSocket}" ] || exit 0
      printf '%s\n%s\n' \
        '{"execute":"qmp_capabilities"}' \
        '{"execute":"system_powerdown"}' \
        | socat - "UNIX-CONNECT:${qmpSocket}" >/dev/null || true

      mainPid="''${MAINPID:-}"
      [ -n "$mainPid" ] || exit 0
      while kill -0 "$mainPid" 2>/dev/null; do
        sleep 1
      done
    '';
  };

  virtiofsdService = share: {
    description = "virtiofsd for the GPU VM ${share.tag} share";
    partOf = [ "vm-gpu.service" ];
    # Pool datasets aren't systemd mounts.
    after = [ "zfs-mount.service" ];
    serviceConfig = {
      Type = "exec";
      ExecStart = lib.concatStringsSep " " (
        [
          (lib.getExe pkgs.virtiofsd)
          "--socket-path ${shareSocket share.tag}"
          "--shared-dir ${share.source}"
          "--cache auto"
          "--inode-file-handles=prefer"
          "--posix-acl"
          "--thread-pool-size ${toString guestVcpus}"
          "--rlimit-nofile 1048576"
        ]
        ++ lib.optional share.readOnly "--readonly"
      );
      Restart = "no";
    };
  };
in
{
  options.vmGpu = {
    hostAddr = lib.mkOption {
      type = lib.types.str;
      default = "10.0.1.1";
      readOnly = true;
    };
    guestAddr = lib.mkOption {
      type = lib.types.str;
      default = "10.0.1.3";
      readOnly = true;
    };
    tap = lib.mkOption {
      type = lib.types.str;
      default = "vm-gpu";
      readOnly = true;
    };
    llamaPort = lib.mkOption {
      type = lib.types.port;
      default = 9931;
      readOnly = true;
    };

    guestModules = lib.mkOption {
      type = lib.types.listOf lib.types.deferredModule;
      default = [ ];
      description = "Extra NixOS modules for the guest";
    };
    shares = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Extra virtiofs shares, shaped like the built-in ones";
    };
    hostPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "TCP ports on the host the guest may connect to";
    };
  };

  config = {
    modules.gateway.services.llama-cpp = {
      name = "llama.cpp";
      domainName = "llama";
      iconUrl = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/llama-cpp.svg";
      addr = "${guestAddr}:${toString llamaPort}";
      category = "Development";
    };

    systemd = {
      tmpfiles.rules = [
        "d ${runDir} 0700 root root -"
      ];

      services = lib.mkMerge [
        (lib.listToAttrs (
          map (share: lib.nameValuePair "vm-gpu-virtiofsd-${share.tag}" (virtiofsdService share)) shares
        ))
        {
          vm-gpu-volume = {
            description = "Provision the GPU VM zvol";
            after = [ "zfs.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = lib.getExe createVolumes;
            };
          };

          vm-gpu = {
            description = "GPU Virtual Machine";

            # A new guest closure changes the launch script, so deploys restart the VM.
            wantedBy = [ "multi-user.target" ];

            requires = [
              "vm-gpu-volume.service"
            ]
            ++ map (share: "vm-gpu-virtiofsd-${share.tag}.service") shares;
            after = [
              "vm-gpu-volume.service"
              "systemd-networkd.service"
            ]
            ++ map (share: "vm-gpu-virtiofsd-${share.tag}.service") shares;

            path = [
              pkgs.util-linux
              pkgs.e2fsprogs
            ];
            preStart = ''
              root="${runDir}/root"
              mkdir -p "$root/nix"
              mount -t ext4 "${nixVolumePath}" "$root/nix"
              trap 'umount "$root/nix"' EXIT
              resize2fs "${nixVolumePath}"
              ${lib.getExe seedStore} "$root"
            '';

            serviceConfig = {
              Type = "exec";
              PrivateMounts = true;
              TimeoutStartSec = "infinity";
              ExecStart = lib.getExe launch;
              ExecStop = lib.getExe shutdown;

              TimeoutStopSec = "600s";
              Restart = "no";

              # VFIO locks the guest's entire address space in the IOMMU.
              LimitMEMLOCK = "infinity";

              AllowedCPUs = guestCpus;
            };
          };
        }
      ];

      network = {
        netdevs."25-${tap}" = {
          netdevConfig = {
            Name = tap;
            Kind = "tap";
          };
          tapConfig = {
            User = "root";
            Group = "root";
          };
        };

        networks."25-${tap}" = {
          matchConfig.Name = tap;
          address = [ "${hostAddr}/32" ];
          routes = [
            {
              Destination = "${guestAddr}/32";
              Scope = "link";
            }
          ];
          networkConfig.ConfigureWithoutCarrier = true;
          linkConfig.RequiredForOnline = false;
        };
      };
    };

    networking = {
      nat = {
        enable = true;
        internalInterfaces = [ tap ];
      };

      firewall.extraCommands = ''
        iptables -N vm-gpu-in 2>/dev/null || iptables -F vm-gpu-in
        iptables -A vm-gpu-in -p tcp --dport 445 -j nixos-fw-accept
        iptables -A vm-gpu-in -p tcp --dport ${toString config.modules.attic.guestPort} -j nixos-fw-accept
        ${
          lib.concatMapStrings (port: ''
            iptables -A vm-gpu-in -p tcp --dport ${toString port} -j nixos-fw-accept
          '') cfg.hostPorts
        }      iptables -A vm-gpu-in -m conntrack --ctstate NEW -j DROP
        iptables -D nixos-fw -i ${tap} -j vm-gpu-in 2>/dev/null || true
        iptables -I nixos-fw -i ${tap} -j vm-gpu-in

        iptables -N vm-gpu-fwd 2>/dev/null || iptables -F vm-gpu-fwd
        iptables -A vm-gpu-fwd -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        ${lib.concatMapStringsSep "\n" (dest: "iptables -A vm-gpu-fwd -d ${dest} -j DROP") [
          "10.0.0.0/8"
          "172.16.0.0/12"
          "192.168.0.0/16"
          "100.64.0.0/10"
          "169.254.0.0/16"
        ]}
        iptables -D FORWARD -i ${tap} -j vm-gpu-fwd 2>/dev/null || true
        iptables -I FORWARD -i ${tap} -j vm-gpu-fwd
      '';

      firewall.extraStopCommands = ''
        iptables -D nixos-fw -i ${tap} -j vm-gpu-in 2>/dev/null || true
        iptables -D FORWARD -i ${tap} -j vm-gpu-fwd 2>/dev/null || true
        iptables -F vm-gpu-in 2>/dev/null || true
        iptables -X vm-gpu-in 2>/dev/null || true
        iptables -F vm-gpu-fwd 2>/dev/null || true
        iptables -X vm-gpu-fwd 2>/dev/null || true
      '';
    };
  };
}
