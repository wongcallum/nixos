{ config, vmLib, ... }:
let
  inherit (config.flake.modules) nixos;
  inherit (config.flake) keys;

  hostname = "vm-ubuntu";
  name = vmLib.vmName hostname;
  net = vmLib.vms.${hostname};
  image = "https://cloud-images.ubuntu.com/releases/26.04/release/ubuntu-26.04-server-cloudimg-amd64.img";
in
{
  # The guest runs Ubuntu, so this is only liz's side: the QEMU VM and its cloud-init seed.
  flake.modules.nixos."${hostname}-host" =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      disk = "/dev/zvol/${config.modules.qemuVms.${hostname}.disk.zvol}";

      userData = {
        inherit hostname;
        ssh_pwauth = false;
        disable_root = true;
        users = [
          {
            name = "ubuntu";
            groups = [ "sudo" ];
            shell = "/bin/bash";
            sudo = "ALL=(ALL) NOPASSWD:ALL";
            lock_passwd = true;
            ssh_authorized_keys = keys.callum ++ keys.colin;
          }
        ];
        packages = [ "prometheus-node-exporter" ];
        package_update = true;
      };

      networkConfig = {
        version = 2;
        ethernets.eth0 = {
          match.macaddress = net.mac;
          set-name = "eth0";
          addresses = [ "${net.guestAddr}/32" ];
          routes = [
            {
              to = "0.0.0.0/0";
              via = net.hostAddr;
              on-link = true;
            }
          ];
          nameservers.addresses = [
            "1.1.1.1"
            "1.0.0.1"
          ];
        };
      };

      # JSON is valid YAML.
      seed = pkgs.runCommand "${hostname}-seed.iso" { nativeBuildInputs = [ pkgs.cdrkit ]; } ''
        printf '#cloud-config\n%s\n' ${lib.escapeShellArg (builtins.toJSON userData)} > user-data
        echo ${lib.escapeShellArg (builtins.toJSON networkConfig)} > network-config
        printf 'instance-id: %s\nlocal-hostname: %s\n' ${hostname} ${hostname} > meta-data
        genisoimage -quiet -output $out -volid cidata -joliet -rock user-data meta-data network-config
      '';

      install = pkgs.writeShellApplication {
        name = "${hostname}-install";
        runtimeInputs = [
          pkgs.curl
          pkgs.qemu-utils
          pkgs.coreutils
        ];
        text = ''
          if [ "''${1-}" != --wipe ]; then
            echo "Overwrites ${disk} with ${image}. Rerun with --wipe." >&2
            exit 1
          fi
          systemctl stop ${hostname}.service
          systemctl start ${hostname}-volume.service
          tmp=$(mktemp -d)
          trap 'rm -rf "$tmp"' EXIT
          curl -fL -o "$tmp/image.img" ${lib.escapeShellArg image}
          qemu-img convert -p -O raw "$tmp/image.img" ${disk}
          systemctl start ${hostname}.service
        '';
      };
    in
    {
      imports = [ nixos.qemu-vms ];

      modules.qemuVms.${hostname} = {
        description = "Ubuntu virtual machine";
        user = hostname;

        smp = "4";
        memory = "4G";

        disk = {
          zvol = vmLib.vmDisk name;
          sizeGiB = 40;
          compression = "lz4";
          serial = name;
        };
        boot = "uefi";

        extraArgs = [
          "-drive"
          "file=${seed},if=none,id=drv-seed,format=raw,readonly=on"
          "-device"
          "virtio-blk-pci,drive=drv-seed,serial=cidata"
        ];

        acceptReplies = true;
      };

      environment.systemPackages = [ install ];
    };
}
