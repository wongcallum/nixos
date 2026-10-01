{
  config,
  inputs,
  lib,
  pkgs,
  self,
  sshKeys,
  ...
}:
let
  stateDir = config.utils.dataDir "gpu-vm";
  runDir = "/run/gpu-vm";

  tap = "vmtap";
  hostAddr = "10.0.1.1";
  guestAddr = "10.0.1.3";
  guestMac = "02:00:00:00:01:03";

  guestCpus = "3-5 9-11";
  guestVcpus = 6;
  guestMemory = "16G";

  qmpSocket = "${runDir}/qmp.sock";
  shareSocket = tag: "${runDir}/${tag}.sock";

  # A separate /nix owns both store paths and their database.
  nixVolume = "rpool/vm/gpu-store";
  nixVolumeSizeGiB = 250;
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
    {
      tag = "work";
      source = "/scratch/gpu";
      mountPoint = "/work";
      readOnly = false;
      neededForBoot = false;
    }
  ];

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
        remote-desktop

        # llama-cpp
      ];

      system.stateVersion = "26.05";
      nixpkgs.config.cudaSupport = true;

      networking = {
        hostName = "linuz";
        useNetworkd = true;
      };

      # Direct kernel boot: no bootloader and a tmpfs root.
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
        nvidia = {
          package = config.boot.kernelPackages.nvidiaPackages.latest;
          # KWin renders through nvidia-drm.
          modesetting.enable = true;
          open = true;
          nvidiaSettings = false;
        };
      };

      powerManagement.enable = false;

      environment = {
        systemPackages = [
          pkgs.ffmpeg-full
          pkgs.nvtopPackages.nvidia
          (pkgs.blender.override { cudaSupport = true; })
        ];

        persistence.${config.modules.persistence.persistDir}.directories = [
          {
            directory = "/home/callum";
            user = "callum";
            group = "users";
            mode = "0700";
          }
        ];
      };

      users.users.root.openssh.authorizedKeys.keys = sshKeys;

      services = {
        openssh.settings = {
          PermitRootLogin = lib.mkForce "yes";
          PasswordAuthentication = lib.mkForce true;
        };

        xserver.videoDrivers = [ "nvidia" ];

        # Stock Moonlight clients; the guest is only reachable through liz.
        punktfunk.host.gamestream = true;
      };

      systemd = {
        network.networks."10-eth" = {
          matchConfig.MACAddress = guestMac;
          address = [ "${guestAddr}/24" ];
          routes = [ { Gateway = hostAddr; } ];
          networkConfig.DNS = [ "1.1.1.1" ];
        };

        tmpfiles.rules = [
          "d /work/llama-cache 0755 root root -"
        ];
      };
    };

  guest = inputs.unstable.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = lib.recursiveUpdate inputs { inherit inputs; };
    modules = [
      self.modules.nixos.base
      self.modules.nixos.global
      guestModule
    ];
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
    name = "gpu-vm-volumes";
    runtimeInputs = [
      config.boot.zfs.package
      pkgs.e2fsprogs
    ];
    text = ''
      created=false
      if ! zfs list -H -o name "${nixVolume}" >/dev/null 2>&1; then
        zfs create -s -V ${nixVolumeSize} \
          -o volblocksize=16K \
          -o compression=lz4 \
          "${nixVolume}"
        created=true
      elif [ "$(zfs get -Hp -o value volsize "${nixVolume}")" -lt ${
        toString (nixVolumeSizeGiB * 1024 * 1024 * 1024)
      } ]; then
        # Grow only; ExecStartPre expands the filesystem to match.
        zfs set volsize=${nixVolumeSize} "${nixVolume}"
      fi
      # udev needs a moment to publish /dev/zvol after creation.
      for _ in $(seq 1 50); do
        [ -e "${nixVolumePath}" ] && break
        sleep 0.1
      done
      if [ ! -b "${nixVolumePath}" ]; then
        echo "Missing GPU VM block device: ${nixVolumePath}" >&2
        exit 1
      fi
      # Only format a volume created by this invocation, never an existing disk.
      if "$created"; then
        mkfs.ext4 "${nixVolumePath}"
      fi
    '';
  };

  # Run only while QEMU is stopped. A rooted local store copies actual files,
  # registers their closure, and keeps guest GC independent of host GC.
  seedStore = pkgs.writeShellApplication {
    name = "gpu-vm-seed-store";
    runtimeInputs = [ config.nix.package ];
    text = ''
      root="$1"
      system="${guest.config.system.build.toplevel}"
      nix --extra-experimental-features nix-command copy \
        --no-check-sigs --to "$root" "$system"
      nix-env --store "$root" \
        --profile "$root/nix/var/nix/profiles/system" --set "$system"
      # Direct kernel boot must remain rooted even if the guest changes profiles.
      mkdir -p "$root/nix/var/nix/gcroots"
      ln -sfn "$system" "$root/nix/var/nix/gcroots/gpu-vm-boot"
    '';
  };

  shareDevices = lib.concatImapStrings (i: share: ''
    -chardev "socket,id=chr-${share.tag},path=${shareSocket share.tag}"
    -device "vhost-user-fs-pci,chardev=chr-${share.tag},tag=${share.tag},addr=0x${toString (i + 5)}"
  '') shares;

  launch = pkgs.writeShellApplication {
    name = "gpu-vm-launch";
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
        -name "vm-gpu,process=gpu-vm"
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

        # Serial console into the journal: the only fallback on a headless GPU.
        -chardev "stdio,id=stdio,signal=off"
        -serial "chardev:stdio"

        -device "virtio-rng-pci"

        # Pinning avoids creation-order-dependent renumbering.
        # discard=unmap lets the guest's TRIM reclaim sparse zvol space.
        -drive "file=${nixVolumePath},if=none,id=drv-nix,format=raw,cache=none,aio=native,discard=unmap,detect-zeroes=unmap"
        -device "virtio-blk-pci,drive=drv-nix,serial=${nixVolumeSerial},addr=0x3"

        -netdev "tap,id=net0,ifname=${tap},script=no,downscript=no,vhost=on"
        -device "virtio-net-pci,netdev=net0,mac=${guestMac},addr=0x4"

        # The root port preserves PCIe capabilities; matching function numbers
        # expose the GPU and HDMI audio as one multifunction device. Both are
        # bound by _vfio.nix before this unit starts.
        # With no emulated VGA the GPU is the boot display, and SeaBIOS would
        # execute its VBIOS and hang; the Linux driver reads the VBIOS from the
        # card itself, so the ROM BAR is not exposed at all.
        -device "pcie-root-port,id=gpu-port,bus=pcie.0,addr=0x2,chassis=1,multifunction=on"
        -device "vfio-pci,host=0000:08:00.0,bus=gpu-port,addr=0x0.0x0,multifunction=on,rombar=0"
        -device "vfio-pci,host=0000:08:00.1,bus=gpu-port,addr=0x0.0x1,rombar=0"

        # A USB controller the guest has no use for on its own, so that USB
        # devices can be hot-attached to it later by id.
        -device "qemu-xhci,id=xhci,addr=0x5"

        ${shareDevices}
        -qmp "unix:${qmpSocket},server=on,wait=off"
      )

      exec qemu-system-x86_64 "''${args[@]}"
    '';
  };

  # Ask the guest to power down cleanly, then keep ExecStop alive until QEMU exits.
  shutdown = pkgs.writeShellApplication {
    name = "gpu-vm-shutdown";
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
    partOf = [ "gpu-vm.service" ];
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
  environment.etc."gpu-vm/README".text = ''
    Guest /nix: ${nixVolumePath} (${nixVolumeSize}, independent ext4 store)
    Before each QEMU start, the host mounts this volume privately, copies and
    registers the configured guest closure, updates its system profile, and
    pins the direct-boot closure at /nix/var/nix/gcroots/gpu-vm-boot.
    The disk is unmounted before QEMU starts. Never mount it on the host while
    QEMU is running. Guest GC and optimisation do not depend on the host store.
  '';

  systemd = {
    tmpfiles.rules = [
      "d ${stateDir} 0755 root root -"
      "d ${stateDir}/etc/ssh 0700 root root -"
      "d ${runDir} 0700 root root -"
      "d /scratch/gpu 0755 root root -"
    ];

    services = lib.mkMerge [
      (lib.listToAttrs (
        map (share: lib.nameValuePair "gpu-vm-virtiofsd-${share.tag}" (virtiofsdService share)) shares
      ))
      {
        gpu-vm-volumes = {
          description = "Provision the GPU VM zvol";
          after = [ "zfs.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = lib.getExe createVolumes;
          };
        };

        gpu-vm = {
          description = "GPU Virtual Machine";

          # unit changes apply through systemctl restart only, not in-VM restart
          restartIfChanged = false;

          requires = [
            "gpu-vm-volumes.service"
          ]
          ++ map (share: "gpu-vm-virtiofsd-${share.tag}.service") shares;
          after = [
            "gpu-vm-volumes.service"
            "systemd-networkd.service"
          ]
          ++ map (share: "gpu-vm-virtiofsd-${share.tag}.service") shares;

          # ExecStartPre completes and unmounts the disk before QEMU opens it.
          # A failed copy aborts startup rather than booting an incomplete store.
          path = [
            pkgs.util-linux
            pkgs.e2fsprogs
          ];
          preStart = ''
            root="${runDir}/root"
            mkdir -p "$root/nix"
            mount -t ext4 "${nixVolumePath}" "$root/nix"
            trap 'umount "$root/nix"' EXIT
            # Online grow after a volsize increase; a no-op otherwise.
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
        address = [ "${hostAddr}/24" ];
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

    #
    #   guest 10.0.1.3 (on the tap)
    #     |
    #     +- to host -> nixos-fw -> gpu-vm-in -+- tcp/445 ---------> ACCEPT
    #     |                                    +- any other NEW ---> DROP
    #     |
    #     +- routed --> FORWARD --> gpu-vm-fwd +- ESTABLISHED,RELATED -> ACCEPT
    #                                          |  (replies to LAN/tailnet clients)
    #                                          +- 10/8, 172.16/12, -> DROP
    #                                          |  192.168/16,
    #                                          |  100.64/10, 169.254/16
    #                                          +- anything else ---> NAT -> internet
    #
    firewall.extraCommands = ''
      iptables -N gpu-vm-in 2>/dev/null || iptables -F gpu-vm-in
      iptables -A gpu-vm-in -p tcp --dport 445 -j nixos-fw-accept
      iptables -A gpu-vm-in -m conntrack --ctstate NEW -j DROP
      iptables -D nixos-fw -i ${tap} -j gpu-vm-in 2>/dev/null || true
      iptables -I nixos-fw -i ${tap} -j gpu-vm-in

      iptables -N gpu-vm-fwd 2>/dev/null || iptables -F gpu-vm-fwd
      iptables -A gpu-vm-fwd -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      ${lib.concatMapStringsSep "\n" (dest: "iptables -A gpu-vm-fwd -d ${dest} -j DROP") [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10" # tailnet (CGNAT)
        "169.254.0.0/16" # link-local, incl. cloud metadata
      ]}
      iptables -D FORWARD -i ${tap} -j gpu-vm-fwd 2>/dev/null || true
      iptables -I FORWARD -i ${tap} -j gpu-vm-fwd
    '';

    firewall.extraStopCommands = ''
      iptables -D nixos-fw -i ${tap} -j gpu-vm-in 2>/dev/null || true
      iptables -D FORWARD -i ${tap} -j gpu-vm-fwd 2>/dev/null || true
      iptables -F gpu-vm-in 2>/dev/null || true
      iptables -X gpu-vm-in 2>/dev/null || true
      iptables -F gpu-vm-fwd 2>/dev/null || true
      iptables -X gpu-vm-fwd 2>/dev/null || true
    '';
  };
}
