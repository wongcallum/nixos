{
  config,
  lib,
  pkgs,
  ...
}:
let
  stateDir = config.utils.dataDir "windows-vm";
  runDir = "/run/windows-vm";

  tap = "vmwin";
  hostAddr = "10.0.1.1";
  guestAddr = "10.0.1.2";
  guestMac = "02:00:00:00:01:02";

  # SMT siblings are n and n+6
  guestCpus = "3-5 9-11";
  guestMemory = "16G";

  ovmf = pkgs.OVMFFull.fd;
  codeImage = "${ovmf}/FV/OVMF_CODE.fd";
  varsTemplate = "${ovmf}/FV/OVMF_VARS.ms.fd";

  nvram = "${stateDir}/OVMF_VARS.fd";
  tpmState = "${stateDir}/tpm";
  qmpSocket = "${runDir}/qmp.sock";
  swtpmSocket = "${runDir}/swtpm.sock";

  # 450G quota
  volumes = [
    {
      name = "win11";
      size = "200G";
      volblocksize = "16K";
    }
    {
      name = "games";
      size = "240G";
      volblocksize = "64K";
    }
  ];

  zvolPath = name: "/dev/zvol/rpool/vm/${name}";

  hyperv = lib.concatStringsSep "," [
    "hv-relaxed"
    "hv-vapic"
    "hv-spinlocks=0x1fff"
    "hv-vpindex"
    "hv-runtime"
    "hv-time"
    "hv-synic"
    "hv-stimer"
    "hv-reset"
    "hv-frequencies"
    "hv-tlbflush"
    "hv-ipi"
  ];

  createVolumes = pkgs.writeShellApplication {
    name = "windows-vm-volumes";
    runtimeInputs = [ config.boot.zfs.package ];
    text = lib.concatMapStringsSep "\n" (vol: ''
      if ! zfs list -H -o name "rpool/vm/${vol.name}" >/dev/null 2>&1; then
        zfs create -s -V ${vol.size} \
          -o volblocksize=${vol.volblocksize} \
          -o compression=lz4 \
          "rpool/vm/${vol.name}"
      fi
      # udev needs a moment to publish /dev/zvol after creation.
      for _ in $(seq 1 50); do
        [ -e "${zvolPath vol.name}" ] && break
        sleep 0.1
      done
    '') volumes;
  };

  launch = pkgs.writeShellApplication {
    name = "windows-vm-launch";
    runtimeInputs = [ pkgs.qemu_kvm ];
    text = ''
      # Type=exec marks swtpm active before its control socket is ready.
      for _ in $(seq 1 100); do
        [ -S "${swtpmSocket}" ] && break
        sleep 0.1
      done

      if [ ! -f "${nvram}" ]; then
        install -m 0600 "${varsTemplate}" "${nvram}"
      fi

      args=(
        -name "windows,process=windows-vm"
        -machine "q35,accel=kvm,smm=on,hpet=off"
        -cpu "host,topoext=on,${hyperv}"
        -smp "6,sockets=1,cores=3,threads=2"
        -m "${guestMemory}"
        -mem-prealloc
        -rtc "base=localtime,driftfix=slew"
        -global "kvm-pit.lost_tick_policy=discard"
        -boot "menu=on"

        # OVMF Secure Boot requires both SMM and secure pflash.
        -global "driver=cfi.pflash01,property=secure,value=on"
        -drive "if=pflash,format=raw,unit=0,readonly=on,file=${codeImage}"
        -drive "if=pflash,format=raw,unit=1,file=${nvram}"

        -chardev "socket,id=chrtpm,path=${swtpmSocket}"
        -tpmdev "emulator,id=tpm0,chardev=chrtpm"
        -device "tpm-crb,tpmdev=tpm0"

        # Pinning avoids creation-order-dependent renumbering, which can make
        # Windows redetect hardware and rerun activation.
        # Exposing the zvols as SSDs lets Windows TRIM reclaim sparse space.
        -device "virtio-scsi-pci,id=scsi0,num_queues=4,addr=0x3"
        -drive "file=${zvolPath "win11"},if=none,id=drv-win11,format=raw,cache=none,aio=native,discard=unmap,detect-zeroes=unmap"
        -device "scsi-hd,drive=drv-win11,bus=scsi0.0,bootindex=1,rotation_rate=1"
        -drive "file=${zvolPath "games"},if=none,id=drv-games,format=raw,cache=none,aio=native,discard=unmap,detect-zeroes=unmap"
        -device "scsi-hd,drive=drv-games,bus=scsi0.0,rotation_rate=1"

        -netdev "tap,id=net0,ifname=${tap},script=no,downscript=no,vhost=on"
        -device "virtio-net-pci,netdev=net0,mac=${guestMac},addr=0x4"

        # The root port preserves PCIe capabilities; matching function numbers
        # expose the GPU and HDMI audio as one multifunction device. Both are
        # bound by _vfio.nix before this unit starts.
        -device "pcie-root-port,id=gpu-port,bus=pcie.0,addr=0x2,chassis=1,multifunction=on"
        -device "vfio-pci,host=0000:08:00.0,bus=gpu-port,addr=0x0.0x0,multifunction=on"
        -device "vfio-pci,host=0000:08:00.1,bus=gpu-port,addr=0x0.0x1"

        # Keep this enabled: VNC is the only firmware and boot fallback on this
        # headless host. Apollo's virtual display remains primary in Windows.
        -vga none
        -device "VGA,id=vga0,addr=0x1"
        -display none
        -vnc "127.0.0.1:1"
        -device "qemu-xhci,id=xhci,addr=0x5"
        -device "usb-tablet,bus=xhci.0"
        -device "usb-kbd,bus=xhci.0"

        # A headless GPU has no HDMI playback endpoint. The emulated codec gives
        # Apollo a stable loopback source; audiodev=none discards host output.
        -audiodev "none,id=snd0"
        -device "ich9-intel-hda,id=hda,addr=0x6"
        -device "hda-duplex,bus=hda.0,audiodev=snd0"

        -qmp "unix:${qmpSocket},server=on,wait=off"
      )

      if [ -f "${stateDir}/install.iso" ]; then
        args+=(
          -drive "file=${stateDir}/install.iso,if=none,id=cd-install,media=cdrom,readonly=on"
          -device "ide-cd,bus=ide.0,drive=cd-install,bootindex=2"
        )
      fi
      if [ -f "${stateDir}/virtio-win.iso" ]; then
        args+=(
          -drive "file=${stateDir}/virtio-win.iso,if=none,id=cd-virtio,media=cdrom,readonly=on"
          -device "ide-cd,bus=ide.1,drive=cd-virtio"
        )
      fi

      exec qemu-system-x86_64 "''${args[@]}"
    '';
  };

  # Ask Windows to unmount cleanly, then keep ExecStop alive until QEMU exits.
  shutdown = pkgs.writeShellApplication {
    name = "windows-vm-shutdown";
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
in
{
  modules.gateway.services.apollo = {
    name = "Apollo";
    domainName = "apollo";
    addr = "https://${guestAddr}:47990";
    tlsInsecureSkipVerify = true;
    category = "Administration";
    iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/sunshine.svg";
  };

  systemd = {
    tmpfiles.rules = [
      "d ${stateDir} 0700 root root -"
      "d ${tpmState} 0700 root root -"
      "d ${runDir} 0700 root root -"
    ];

    services = {
      windows-vm-volumes = {
        description = "Provision the Windows VM zvols";
        after = [ "zfs.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = lib.getExe createVolumes;
        };
      };

      windows-vm-swtpm = {
        description = "Software TPM 2.0 for the Windows VM";
        partOf = [ "windows-vm.service" ];
        serviceConfig = {
          Type = "exec";
          ExecStart = lib.concatStringsSep " " [
            (lib.getExe' pkgs.swtpm "swtpm")
            "socket"
            "--tpm2"
            "--tpmstate dir=${tpmState}"
            "--ctrl type=unixio,path=${swtpmSocket}"
            "--log level=1"
          ];
          Restart = "no";
        };
      };

      windows-vm = {
        description = "Windows 11 Virtual Machine";

        # unit changes apply through systemctl restart only, not in-VM restart
        restartIfChanged = false;

        requires = [
          "windows-vm-volumes.service"
          "windows-vm-swtpm.service"
        ];
        after = [
          "windows-vm-volumes.service"
          "windows-vm-swtpm.service"
          "systemd-networkd.service"
        ];

        serviceConfig = {
          Type = "exec";
          ExecStart = lib.getExe launch;
          ExecStop = lib.getExe shutdown;

          TimeoutStopSec = "180s";
          Restart = "no";

          # VFIO locks the guest's entire address space in the IOMMU.
          LimitMEMLOCK = "infinity";

          AllowedCPUs = guestCpus;
        };
      };
    };

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
    #   guest 10.0.1.2 (on the tap)
    #     |
    #     +- to host -> nixos-fw -> windows-vm-in -+- tcp/445 ---------> ACCEPT
    #     |                                        +- any other NEW ---> DROP
    #     |
    #     +- routed --> FORWARD --> windows-vm-fwd +- 10/8, 172.16/12, -> DROP
    #                                              |  192.168/16,
    #                                              |  100.64/10, 169.254/16
    #                                              +- anything else ---> NAT -> internet
    #
    firewall.extraCommands = ''
      iptables -N windows-vm-in 2>/dev/null || iptables -F windows-vm-in
      iptables -A windows-vm-in -p tcp --dport 445 -j nixos-fw-accept
      iptables -A windows-vm-in -m conntrack --ctstate NEW -j DROP
      iptables -D nixos-fw -i ${tap} -j windows-vm-in 2>/dev/null || true
      iptables -I nixos-fw -i ${tap} -j windows-vm-in

      iptables -N windows-vm-fwd 2>/dev/null || iptables -F windows-vm-fwd
      ${lib.concatMapStringsSep "\n" (dest: "iptables -A windows-vm-fwd -d ${dest} -j DROP") [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10" # tailnet (CGNAT)
        "169.254.0.0/16" # link-local, incl. cloud metadata
      ]}
      iptables -D FORWARD -i ${tap} -j windows-vm-fwd 2>/dev/null || true
      iptables -I FORWARD -i ${tap} -j windows-vm-fwd
    '';

    firewall.extraStopCommands = ''
      iptables -D nixos-fw -i ${tap} -j windows-vm-in 2>/dev/null || true
      iptables -D FORWARD -i ${tap} -j windows-vm-fwd 2>/dev/null || true
      iptables -F windows-vm-in 2>/dev/null || true
      iptables -X windows-vm-in 2>/dev/null || true
      iptables -F windows-vm-fwd 2>/dev/null || true
      iptables -X windows-vm-fwd 2>/dev/null || true
    '';
  };

  environment.etc."windows-vm/README".text = ''
    Guest network: ${guestAddr}/24, gateway ${hostAddr}, DNS 1.1.1.1
    VNC console:   ssh -L 5901:127.0.0.1:5901 liz  (then connect to :5901)
    Install media: drop install.iso and virtio-win.iso into ${stateDir}
  '';
}
