{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./_hardware-configuration.nix

    ./_fonts.nix
  ];

  boot.loader.limine.enable = true;

  zramSwap = {
    enable = true;
    priority = 100;
    algorithm = "lzo";
    memoryPercent = 50;
  };

  networking.hostName = "wky";
  networking.networkmanager.enable = true;
  services.resolved.enable = true;

  services.tailscale.enable = true;

  programs.nix-ld.enable = true;

  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.initrd.kernelModules = [ "wl" ];
  boot.kernel.sysctl."ibt" = "off";

  time.timeZone = "Australia/Sydney";
  i18n.defaultLocale = "en_AU.UTF-8";

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  powerManagement.enable = true;
  services.tuned.enable = true;
  services.upower.enable = true;

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "callum";
    dataDir = "/home/callum";
  };

  hardware.bluetooth.enable = true;
  hardware.enableAllFirmware = true;

  nixpkgs.config = {
    allowUnfree = true;
    allowInsecurePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [ "broadcom-sta" ];
  };

  nixpkgs.overlays = [
    inputs.yazi.overlays.default
  ];

  programs.niri.enable = true;

  xdg.portal.enable = true;

  services.printing.enable = true;

  programs.virt-manager.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu.package = pkgs.qemu_kvm;
    qemu.runAsRoot = true;
    qemu.vhostUserPackages = [ pkgs.virtiofsd ];
  };

  virtualisation.docker = {
    enable = true;
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    wireplumber.extraConfig."11-bluetooth-policy" = {
      "wireplumber.settings" = {
        "bluetooth.autoswitch-to-headset-profile" = false;
      };
    };
    extraConfig.pipewire = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 2048;
        "default.clock.min-quantum" = 2048;
        "default.clock.max-quantum" = 8192;
      };
    };
  };

  programs.fish.enable = true;
  documentation.man.cache.enable = false; # prevent extra long build times

  programs.kdeconnect.enable = true;

  users.users.callum = {
    isNormalUser = true;
    home = "/home/callum";
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
      "adbusers"
      "libvirtd"
    ];
  };

  services.udisks2.enable = true;

  environment.systemPackages = with pkgs; [
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    kdePackages.qttools
    vim
    wget
    git
    foot
    adwaita-icon-theme
    nmap
    qalculate-gtk
    vesktop
    obsidian
    nautilus
    scrcpy
    android-tools
    blueman
    pavucontrol
    libreoffice-fresh
    xournalpp
    btop
    nixd
    nixfmt
    unzip
    kdePackages.okular
    (texliveBasic.withPackages (
      ps: with ps; [
        collection-xetex
        collection-latex
        collection-basic
        collection-luatex
        collection-binextra
        collection-fontutils
        collection-latexextra
        collection-bibtexextra
        collection-mathscience
        collection-plaingeneric
        collection-formatsextra
        collection-latexrecommended
        collection-fontsrecommended
      ]
    ))
    zellij
    wl-clipboard
    lua-language-server
    ncdu
    foliate
    markdown-oxide
    zathura
    tinymist
    websocat
    dnsmasq
  ];

  programs.firefox = {
    enable = true;
    autoConfig = ''
      // Any comment. You must start the file with a single-line comment!
      var { classes: Cc, interfaces: Ci, utils: Cu } = Components;

      // Set new tab page
      try {
        ChromeUtils.importESModule(
          "resource:///modules/AboutNewTab.sys.mjs",
        ).AboutNewTab.newTabURL = "https://prism.tower.7sref";
      } catch (e) {
        Cu.reportError(e);
      } // report errors in the Browser Console

      // Auto focus new tab content
      try {
        const { BrowserWindowTracker } = ChromeUtils.importESModule(
          "resource:///modules/BrowserWindowTracker.sys.mjs",
        );
        const Services = globalThis.Services;
        Services.obs.addObserver((event) => {
          window = BrowserWindowTracker.getTopWindow();
          window.gBrowser.selectedBrowser.focus();
        }, "browser-open-newtab-start");
      } catch (e) {
        Cu.reportError(e);
      }
    '';
  };

  hardware.facetimehd.enable = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    trusted-users = [ "callum" ];

    extra-substituters = [ "https://yazi.cachix.org" ];
    extra-trusted-public-keys = [ "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k=" ];

    download-buffer-size = 524288000;
  };

  nix.buildMachines = [
    {
      hostName = "acid";
      sshUser = "callum";
      system = "x86_64-linux";
      maxJobs = 6;
      speedFactor = 2;
      supportedFeatures = [
        "nixos-test"
        "benchmark"
        "big-parallel"
        "kvm"
      ];
    }
  ];

  system.stateVersion = "25.11"; # no
}
