# Windows 11 guest with the RTX 3060 passed through, for Adobe and light gaming.
#
# Deliberately raw QEMU under systemd rather than libvirt: liz rolls back
# rpool/nixos/root@blank on every boot, so a `virsh define`d domain would not
# survive a reboot. Generating the domain here keeps it in git and makes the
# rollback irrelevant. `modules/libvirt.nix` stays imported for one-off VMs.
#
# The card is already bound to vfio-pci at boot by ./_vfio.nix, so there is no
# bind/unbind dance here — the devices are simply handed to QEMU.
#
# On demand only: `systemctl start windows-vm`. Reaching it is Moonlight over
# Tailscale, which runs *inside* the guest, so nothing is forwarded in.
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

  # liz pairs SMT siblings n and n+6, so "3-5 9-11" is cores 3, 4 and 5 in
  # full. This is a ceiling on the guest, not a reservation away from the
  # host: with no isolcpus and no global CPUAffinity, host services keep the
  # run of all twelve logical CPUs. What it buys is three cores the guest can
  # never contend for.
  guestCpus = "3-5 9-11";
  guestMemory = "24G";

  ovmf = pkgs.OVMFFull.fd;
  codeImage = "${ovmf}/FV/OVMF_CODE.fd";
  # The .ms varstore ships with Microsoft's keys already enrolled, which is
  # what lets a stock Windows ISO boot with Secure Boot on.
  varsTemplate = "${ovmf}/FV/OVMF_VARS.ms.fd";

  nvram = "${stateDir}/OVMF_VARS.fd";
  tpmState = "${stateDir}/tpm";
  qmpSocket = "${runDir}/qmp.sock";
  swtpmSocket = "${runDir}/swtpm.sock";

  # Sparse: the 450G quota on rpool/vm is the guardrail, and these sum to 440G.
  # lz4 over the pool's inherited zstd — Windows and Adobe binaries do not
  # repay zstd's latency on small random IO, and game assets are already
  # compressed (the same call made for scratch/games).
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
      # swtpm is a separate unit; give its control socket a moment to appear.
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

        # Secure Boot needs SMM plus a secure-flagged code image.
        -global "driver=cfi.pflash01,property=secure,value=on"
        -drive "if=pflash,format=raw,unit=0,readonly=on,file=${codeImage}"
        -drive "if=pflash,format=raw,unit=1,file=${nvram}"

        -chardev "socket,id=chrtpm,path=${swtpmSocket}"
        -tpmdev "emulator,id=tpm0,chardev=chrtpm"
        -device "tpm-crb,tpmdev=tpm0"

        # rotation_rate=1 makes Windows treat the volumes as SSDs and issue
        # TRIM, without which discard=unmap never fires and the sparse zvols
        # creep towards their full provisioned size and never come back.
        -device "virtio-scsi-pci,id=scsi0,num_queues=4"
        -drive "file=${zvolPath "win11"},if=none,id=drv-win11,format=raw,cache=none,aio=native,discard=unmap,detect-zeroes=unmap"
        -device "scsi-hd,drive=drv-win11,bus=scsi0.0,bootindex=1,rotation_rate=1"
        -drive "file=${zvolPath "games"},if=none,id=drv-games,format=raw,cache=none,aio=native,discard=unmap,detect-zeroes=unmap"
        -device "scsi-hd,drive=drv-games,bus=scsi0.0,rotation_rate=1"

        -netdev "tap,id=net0,ifname=${tap},script=no,downscript=no,vhost=on"
        -device "virtio-net-pci,netdev=net0,mac=${guestMac}"

        # Already vfio-bound at boot, so no bind/unbind is needed here.
        #
        # Behind a pcie-root-port rather than straight onto pcie.0, so the card
        # keeps its PCIe capabilities in the guest, and pinned to one slot with
        # matching function numbers so the GPU and its HDMI audio arrive as a
        # single multifunction device the way they appear on the host.
        #
        # No x-vga=on: that is the legacy-VGA path SeaBIOS needed, and under
        # OVMF it only fights the emulated adapter kept below.
        -device "pcie-root-port,id=gpu-port,bus=pcie.0,addr=0x3,chassis=1,multifunction=on"
        -device "vfio-pci,host=0000:08:00.0,bus=gpu-port,addr=0x0.0x0,multifunction=on"
        -device "vfio-pci,host=0000:08:00.1,bus=gpu-port,addr=0x0.0x1"

        # Kept permanently, disabled inside Windows' Device Manager. Windows
        # ignores it for rendering, but VNC still shows UEFI, the boot manager
        # and early boot — the only Windows-side console on a host with no
        # display and no serial cable.
        -vga std
        -display none
        -vnc "127.0.0.1:1"
        -device "qemu-xhci,id=xhci"
        -device "usb-tablet,bus=xhci.0"
        -device "usb-kbd,bus=xhci.0"

        -qmp "unix:${qmpSocket},server=on,wait=off"
      )

      # Attach install media only while it is present, so the transition from
      # install to steady state needs no config change. The disk holds
      # bootindex=1, so an ISO left in place is only reached when C: is empty.
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

  # Without this a host reboot SIGKILLs QEMU and Windows comes back to a dirty
  # NTFS volume every single time.
  shutdown = pkgs.writeShellApplication {
    name = "windows-vm-shutdown";
    runtimeInputs = [ pkgs.socat ];
    text = ''
      [ -S "${qmpSocket}" ] || exit 0
      printf '%s\n%s\n' \
        '{"execute":"qmp_capabilities"}' \
        '{"execute":"system_powerdown"}' \
        | socat - "UNIX-CONNECT:${qmpSocket}" >/dev/null || true
    '';
  };
in
{
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
        description = "Windows 11 guest (RTX 3060 passthrough)";

        # No wantedBy: on demand only, via `systemctl start windows-vm`.
        requires = [
          "windows-vm-volumes.service"
          "windows-vm-swtpm.service"
        ];
        after = [
          "windows-vm-volumes.service"
          "windows-vm-swtpm.service"
          # The tap is what matters, not general connectivity — and liz
          # disables wait-online, so ordering on network-online.target would be
          # a no-op at best and a stall at worst.
          "systemd-networkd.service"
        ];

        serviceConfig = {
          Type = "exec";
          ExecStart = lib.getExe launch;
          ExecStop = lib.getExe shutdown;

          # Windows takes its time; systemd only escalates to SIGTERM after
          # this.
          TimeoutStopSec = "180s";
          Restart = "no";

          # VFIO pins the entire guest address space into the IOMMU, so all
          # 24 GiB is locked for the lifetime of the VM. Without this the guest
          # refuses to start.
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

    # Deliberately not microvmLib.mkHostNetworking: its rules go in with `-I`
    # into nixos-fw, so layering an ACCEPT for SMB on top would depend on
    # insertion order surviving every rebuild. A dedicated chain is ordered by
    # construction — the guest reaches the host on 445 and nothing else, and
    # cannot be forwarded onto the LAN or the tailnet at all.
    #
    # Tailscale inside the guest is unaffected: it talks to public DERP and
    # peer endpoints, and tailnet traffic is encapsulated by the time it
    # leaves the guest.
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

  # The guest is configured statically at ${guestAddr}/24 with ${hostAddr} as
  # its gateway; there is no DHCP server on this link.
  environment.etc."windows-vm/README".text = ''
    Guest network: ${guestAddr}/24, gateway ${hostAddr}, DNS 1.1.1.1
    VNC console:   ssh -L 5901:127.0.0.1:5901 liz  (then connect to :5901)
    Install media: drop install.iso and virtio-win.iso into ${stateDir}
  '';
}
