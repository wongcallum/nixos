{ vmLib, ... }:
{
  # Both vm-*-host aspects import this; the key makes NixOS import it once.
  flake.modules.nixos.qemu-vms.key = "qemu-vms";
  flake.modules.nixos.qemu-vms.imports = [
    (
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        vmModule =
          { name, ... }:
          {
            options = {
              description = lib.mkOption { type = lib.types.str; };
              vhostNet = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              netPciAddr = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };

              user = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Run QEMU sandboxed as this system user instead of root";
              };

              cpu = lib.mkOption {
                type = lib.types.str;
                default = "host";
              };
              smp = lib.mkOption { type = lib.types.str; };
              memory = lib.mkOption { type = lib.types.str; };
              allowedCpus = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };

              disk = {
                zvol = lib.mkOption { type = lib.types.str; };
                sizeGiB = lib.mkOption { type = lib.types.ints.positive; };
                compression = lib.mkOption { type = lib.types.str; };
                serial = lib.mkOption { type = lib.types.str; };
                pciAddr = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                mkfs = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "ext4";
                  description = "Filesystem to create on a new zvol";
                };
              };

              boot = lib.mkOption {
                type = lib.types.either (lib.types.enum [ "uefi" ]) (
                  lib.types.submodule {
                    options = {
                      kernel = lib.mkOption { type = lib.types.str; };
                      initrd = lib.mkOption { type = lib.types.str; };
                      cmdline = lib.mkOption { type = lib.types.str; };
                    };
                  }
                );
              };

              shares = lib.mkOption {
                type = lib.types.listOf lib.types.attrs;
                default = [ ];
                description = "virtiofs shares, as { tag, source, readOnly }";
              };

              extraArgs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "QEMU arguments placed before the disk and network devices";
              };

              hostPorts = lib.mkOption {
                type = lib.types.listOf lib.types.port;
                default = [ ];
                description = "TCP ports on the host the guest may connect to";
              };
            };

            config.description = lib.mkDefault name;
          };

        mkVm =
          name: vm:
          let
            tap = name;
            link = vmLib.mkHostLink name { inherit (vm) hostPorts; };
            owner = if vm.user == null then "root" else vm.user;
            runDir = "/run/${name}";
            qmpSocket = "${runDir}/qmp.sock";
            shareSocket = tag: "${runDir}/${tag}.sock";
            disk = "/dev/zvol/${vm.disk.zvol}";
            firmware = "${pkgs.OVMF.fd}/FV";
            useMemfd = vm.shares != [ ];
            pciAddr = addr: lib.optionalString (addr != null) ",addr=${addr}";

            createVolume = pkgs.writeShellApplication {
              name = "${name}-volume";
              runtimeInputs = [
                config.boot.zfs.package
                pkgs.e2fsprogs
              ];
              text = ''
                ${lib.optionalString (vm.disk.mkfs != null) "created=false"}
                if ! zfs list -H -o name "${vm.disk.zvol}" >/dev/null 2>&1; then
                  zfs create -p -s -V ${toString vm.disk.sizeGiB}G \
                    -o volblocksize=16K \
                    -o compression=${vm.disk.compression} \
                    "${vm.disk.zvol}"
                  ${lib.optionalString (vm.disk.mkfs != null) "created=true"}
                elif [ "$(zfs get -Hp -o value volsize "${vm.disk.zvol}")" -lt ${
                  toString (vm.disk.sizeGiB * 1024 * 1024 * 1024)
                } ]; then
                  zfs set volsize=${toString vm.disk.sizeGiB}G "${vm.disk.zvol}"
                fi
                for _ in $(seq 1 50); do
                  [ -b "${disk}" ] && break
                  sleep 0.1
                done
                if [ ! -b "${disk}" ]; then
                  echo "Missing ${name} block device: ${disk}" >&2
                  exit 1
                fi
                ${lib.optionalString (vm.disk.mkfs != null) ''
                  if "$created"; then
                    mkfs.${vm.disk.mkfs} "${disk}"
                  fi
                ''}
              '';
            };

            shareDevices = lib.concatImapStrings (i: share: ''
              -chardev "socket,id=chr-${share.tag},path=${shareSocket share.tag}"
              -device "vhost-user-fs-pci,chardev=chr-${share.tag},tag=${share.tag},addr=0x${toString (i + 5)}"
            '') vm.shares;

            launch = pkgs.writeShellApplication {
              name = "${name}-launch";
              runtimeInputs = [
                pkgs.qemu_kvm
                pkgs.coreutils
              ];
              text = ''
                ${lib.optionalString (vm.boot == "uefi") ''
                  install -m 600 ${firmware}/OVMF_VARS.fd ${runDir}/OVMF_VARS.fd
                ''}
                ${lib.optionalString useMemfd ''
                  # Type=exec marks virtiofsd active before its socket is ready.
                  for sock in ${lib.concatMapStringsSep " " (share: shareSocket share.tag) vm.shares}; do
                    for _ in $(seq 1 100); do
                      [ -S "$sock" ] && break
                      sleep 0.1
                    done
                  done
                ''}

                args=(
                  -name "${name},process=${name}"
                  -machine "q35,accel=kvm${lib.optionalString useMemfd ",memory-backend=mem"}"
                  -cpu "${vm.cpu}"
                  -smp "${vm.smp}"
                  -m "${vm.memory}"
                  ${lib.optionalString useMemfd ''
                    # virtiofs needs guest memory in a shareable backend.
                    -object "memory-backend-memfd,id=mem,size=${vm.memory},share=on,prealloc=on"
                  ''}
                  -nodefaults
                  -no-user-config
                  -display none

                  ${
                    if vm.boot == "uefi" then
                      ''
                        -drive "if=pflash,format=raw,readonly=on,file=${firmware}/OVMF_CODE.fd"
                        -drive "if=pflash,format=raw,file=${runDir}/OVMF_VARS.fd"
                      ''
                    else
                      ''
                        -kernel "${vm.boot.kernel}"
                        -initrd "${vm.boot.initrd}"
                        -append "${vm.boot.cmdline}"
                      ''
                  }

                  -chardev "stdio,id=stdio,signal=off"
                  -serial "chardev:stdio"

                  -device "virtio-rng-pci"

                  ${lib.concatMapStringsSep "\n" lib.escapeShellArg vm.extraArgs}

                  -drive "file=${disk},if=none,id=drv-disk,format=raw,cache=none,aio=native,discard=unmap,detect-zeroes=unmap"
                  -device "virtio-blk-pci,drive=drv-disk,serial=${vm.disk.serial}${pciAddr vm.disk.pciAddr}"

                  -netdev "tap,id=net0,ifname=${tap},script=no,downscript=no${lib.optionalString vm.vhostNet ",vhost=on"}"
                  -device "virtio-net-pci,netdev=net0,mac=${vmLib.vms.${name}.mac}${pciAddr vm.netPciAddr}"

                  ${shareDevices}
                  -qmp "unix:${qmpSocket},server=on,wait=off"
                )

                exec qemu-system-x86_64 "''${args[@]}"
              '';
            };

            shutdown = pkgs.writeShellApplication {
              name = "${name}-shutdown";
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
              description = "virtiofsd for ${name}'s ${share.tag} share";
              partOf = [ "${name}.service" ];
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
                    "--thread-pool-size ${toString (lib.toInt (lib.head (lib.splitString "," vm.smp)))}"
                    "--rlimit-nofile 1048576"
                  ]
                  ++ lib.optional share.readOnly "--readonly"
                );
                Restart = "no";
              };
            };

            shareUnits = map (share: "${name}-virtiofsd-${share.tag}.service") vm.shares;
          in
          {
            users = lib.mkIf (vm.user != null) {
              users.${vm.user} = {
                isSystemUser = true;
                group = vm.user;
              };
              groups.${vm.user} = { };
            };

            systemd = {
              # virtiofsd creates its sockets before the VM starts, so it can't be a RuntimeDirectory.
              tmpfiles.rules = lib.optional useMemfd "d ${runDir} 0700 ${owner} ${owner} -";

              services = lib.mkMerge [
                (lib.listToAttrs (
                  map (share: lib.nameValuePair "${name}-virtiofsd-${share.tag}" (virtiofsdService share)) vm.shares
                ))
                {
                  "${name}-volume" = {
                    description = "Provision the ${name} zvol";
                    after = [ "zfs.target" ];
                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = true;
                      ExecStart = lib.getExe createVolume;
                    };
                  };

                  ${name} = {
                    inherit (vm) description;
                    wantedBy = [ "multi-user.target" ];
                    requires = [ "${name}-volume.service" ] ++ shareUnits;
                    after = [
                      "${name}-volume.service"
                      "systemd-networkd.service"
                    ]
                    ++ shareUnits;

                    serviceConfig = lib.mkMerge [
                      {
                        Type = "exec";
                        ExecStart = lib.getExe launch;
                        ExecStop = lib.getExe shutdown;
                        AllowedCPUs = lib.mkIf (vm.allowedCpus != null) vm.allowedCpus;
                      }
                      (lib.mkIf (!useMemfd) {
                        RuntimeDirectory = name;
                        RuntimeDirectoryMode = "0700";
                      })
                      (lib.mkIf (vm.user != null) {
                        ExecStartPre = "+${lib.getExe' pkgs.coreutils "chown"} ${vm.user} ${disk}";
                        User = vm.user;
                        Group = vm.user;
                        SupplementaryGroups = [ "kvm" ];

                        DevicePolicy = "closed";
                        DeviceAllow = [
                          "/dev/kvm rw"
                          "/dev/net/tun rw"
                          "block-zvol rw"
                        ];
                        NoNewPrivileges = true;
                        PrivateTmp = true;
                        ProtectSystem = "strict";
                        ProtectHome = true;
                        ProtectKernelTunables = true;
                        ProtectKernelModules = true;
                        ProtectControlGroups = true;
                      })
                    ];
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
                    User = owner;
                    Group = owner;
                  };
                };
                inherit (link.systemd.network) networks;
              };
            };

            inherit (link) networking;
          };
      in
      {
        options.modules.qemuVms = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule vmModule);
          default = { };
          description = "QEMU VMs that liz runs from zvols on a point-to-point tap link";
        };

        # Merged per attribute: building `config` from config.modules.qemuVms would recurse.
        config =
          let
            vms = lib.mapAttrsToList mkVm config.modules.qemuVms;
          in
          lib.genAttrs [ "users" "systemd" "networking" ] (attr: lib.mkMerge (map (vm: vm.${attr}) vms));
      }
    )
  ];
}
