{ config, microvmLib, ... }:
let
  inherit (config.flake.modules) nixos;
  inherit (config.flake) keys;
in
{
  flake.nixpkgs.vm-gpu = "unstable";

  flake.modules.nixos."hosts/nixos/vm-gpu" =
    { pkgs, ... }:
    {
      imports = [
        (microvmLib.mkGuestModule {
          n = 3;
          hostname = "vm-gpu";
        })
      ]
      ++ (with nixos; [
        persistence

        ssh

        llama-cpp
      ]);

      system.stateVersion = "26.05";

      microvm = {
        mem = 4096;
        vcpu = 4;
        devices = [
          {
            bus = "pci";
            path = "0000:08:00.0";
          }
          {
            bus = "pci";
            path = "0000:08:00.1";
          }
        ];
        shares = [
          {
            tag = "work";
            source = "/scratch/gpu";
            mountPoint = "/work";
            proto = "virtiofs";
          }
        ];
      };

      services.xserver.videoDrivers = [ "nvidia" ];
      hardware = {
        graphics.enable = true;
        nvidia = {
          modesetting.enable = false;
          open = true;
        };
      };

      environment = {
        systemPackages = [
          pkgs.ffmpeg-full
          pkgs.nvtopPackages.nvidia
        ];
      };

      systemd.tmpfiles.rules = [
        "d /work/llama-cache 0755 root root -"
      ];

      users.users.root.openssh.authorizedKeys.keys = keys.callum;
    };
}
