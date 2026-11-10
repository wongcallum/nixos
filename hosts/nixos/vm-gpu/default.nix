{ config, vmLib, ... }:
let
  inherit (config.flake.modules) nixos;
  hosts = config.flake.nixosConfigurations;

  hostname = "vm-gpu";
  net = vmLib.vms.${hostname};
  llamaPort = 9931;

  stateDir = vmLib.vmDir "gpu";
  nixVolumeSerial = "nix";
in
{
  flake.nixpkgs.${hostname} = "unstable";

  flake.modules.nixos = {
    "hosts/nixos/${hostname}" =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        imports = with nixos; [
          (vmLib.mkGuestNetwork hostname)

          persistence
          secrets

          callum

          ssh

          metrics

          llama-cpp
          frigate
        ];

        options.vmGpu.shares = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
          description = "virtiofs shares from liz, as { tag, source, mountPoint, readOnly, neededForBoot }";
        };

        config = {
          system.stateVersion = "26.05";
          nixpkgs.config.cudaSupport = true;

          vmGpu.shares = lib.mkBefore [
            {
              tag = "persist";
              source = stateDir;
              mountPoint = "/persist";
              readOnly = false;
              neededForBoot = true;
            }
          ];

          modules = {
            # The guest doesn't get the password secret.
            users.callum.lockPassword = true;
            # The gateway's hostname doesn't resolve here, so use liz's guest port.
            attic.endpoint = "http://${net.hostAddr}:${toString config.modules.attic.guestPort}/";
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
              ) config.vmGpu.shares
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
      };

    # liz's side: storage and the QEMU VM.
    "${hostname}-host" =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        guest = hosts.${hostname};
        nixVolumePath = "/dev/zvol/${config.modules.qemuVms.${hostname}.disk.zvol}";

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
      in
      {
        imports = [
          nixos.qemu-vms
          (vmLib.mkVmStorage {
            name = "gpu";
            requiredBy = [
              "vm-gpu-volume.service"
              "vm-gpu-virtiofsd-persist.service"
            ];
          })
        ];

        modules.qemuVms.${hostname} = {
          description = "GPU Virtual Machine";
          vhostNet = true;
          netPciAddr = "0x4";

          cpu = "host,topoext=on";
          smp = "6,sockets=1,cores=3,threads=2";
          memory = "8G";
          allowedCpus = "3-5 9-11";

          disk = {
            zvol = vmLib.vmDisk "gpu";
            sizeGiB = 100;
            compression = "lz4";
            serial = nixVolumeSerial;
            pciAddr = "0x3";
            mkfs = "ext4";
          };

          boot = {
            kernel = "${guest.config.boot.kernelPackages.kernel}/${guest.config.system.boot.loader.kernelFile}";
            initrd = "${guest.config.system.build.initialRamdisk}/${guest.config.system.boot.loader.initrdFile}";
            cmdline = toString (
              guest.config.boot.kernelParams ++ [ "init=${guest.config.system.build.toplevel}/init" ]
            );
          };

          inherit (guest.config.vmGpu) shares;

          extraArgs = [
            # As the boot display, the GPU's VBIOS would hang SeaBIOS, so hide its ROM.
            "-device"
            "pcie-root-port,id=gpu-port,bus=pcie.0,addr=0x2,chassis=1,multifunction=on"
            "-device"
            "vfio-pci,host=0000:08:00.0,bus=gpu-port,addr=0x0.0x0,multifunction=on,rombar=0"
            "-device"
            "vfio-pci,host=0000:08:00.1,bus=gpu-port,addr=0x0.0x1,rombar=0"
            # Lets USB devices be hot-attached later.
            "-device"
            "qemu-xhci,id=xhci,addr=0x5"
          ];

          hostPorts = [
            445
            config.modules.attic.guestPort
          ];
          acceptReplies = true;
        };

        # A new guest closure changes the launch script, so deploys restart the VM.
        systemd.services.${hostname} = {
          path = [
            pkgs.util-linux
            pkgs.e2fsprogs
          ];
          preStart = ''
            root="/run/${hostname}/root"
            mkdir -p "$root/nix"
            mount -t ext4 "${nixVolumePath}" "$root/nix"
            trap 'umount "$root/nix"' EXIT
            resize2fs "${nixVolumePath}"
            ${lib.getExe seedStore} "$root"
          '';
          serviceConfig = {
            PrivateMounts = true;
            TimeoutStartSec = "infinity";
            TimeoutStopSec = "600s";
            # VFIO locks the guest's entire address space in the IOMMU.
            LimitMEMLOCK = "infinity";
          };
        };

        modules.gateway.services.llama-cpp = {
          name = "llama.cpp";
          domainName = "llama";
          iconUrl = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/llama-cpp.svg";
          addr = "${net.guestAddr}:${toString llamaPort}";
          category = "Development";
        };
      };
  };
}
