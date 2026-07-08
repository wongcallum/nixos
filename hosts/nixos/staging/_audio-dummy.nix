# Dummy multi-port audio sink, for testing the DankMaterialShell audio output
# *port selector* on staging.
#
# Why this exists:
#  - The port selector UI (the "tune" button + modal) only appears for a sink
#    that exposes more than one output port, i.e. one that pactl can switch with
#    `set-sink-port`. Real UCM/SOF hardware splits into *single*-port sinks, and
#    virtual/null sinks have no ports at all, so normally there is nothing to
#    exercise the multi-port UI against. This fabricates a genuine ALSA sink with
#    five switchable ports.
#
# How it works (each step is load-bearing — see the inline notes):
#  1. snd-dummy model=ac97 gives a real ALSA card whose fake mixer exposes five
#     *distinct* volume controls: Master, Synth, Line, CD, Mic. (The default
#     snd-dummy model exposes no usable mixer, so ACP can only build one generic
#     port from it — the model matters.)
#  2. A custom ACP (alsa-card-profile) profile-set maps that card to ONE sink
#     with five output *paths*, each bound to a *different* one of those five
#     controls. The distinct binding is the crux: ACP's path_set_condense()
#     drops any path whose control set is a subset of another's, so paths with no
#     (or shared) elements collapse down to a single port. One unique control per
#     path is what keeps all five as separate ports.
#  3. The custom paths + profile-set live in a merged mixer dir (every stock ACP
#     file is symlinked in so all other cards still work) that ACP is pointed at
#     via ACP_PATHS_DIR / ACP_PROFILES_DIR on the pipewire + wireplumber user
#     units.
#  4. A WirePlumber rule assigns the dummy card our profile-set by filename. Note
#     the property is `device.profile-set` — acp reads that, NOT the
#     `api.acp.profile-set` that WirePlumber's own docs mention (it's ignored).
#
# Verify after `nixos-rebuild`:
#   pactl list sinks | grep -A9 snd_dummy          # five dummy-* ports listed
#   SINK=alsa_output.platform-snd_dummy.0.multiport
#   pactl set-sink-port "$SINK" dummy-hdmi          # succeeds, Active Port moves
#
# Caveat: on a VM with no other sound card the dummy becomes the *default* sink,
# so Sunshine/Moonlight audio capture would pick it up (silence). Fine for
# testing the shell; remove the import from ./default.nix when done.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  # name -> the mixer control each path binds. Distinct control per port is what
  # survives path_set_condense(); priorities/labels are just what the UI shows.
  ports = [
    {
      name = "dummy-speaker";
      element = "Master";
      type = "speaker";
      description = "Speaker";
      icon = "audio-speakers";
      priority = 100;
    }
    {
      name = "dummy-headphones";
      element = "Synth";
      type = "headphones";
      description = "Headphones";
      icon = "audio-headphones";
      priority = 200;
    }
    {
      name = "dummy-hdmi";
      element = "Line";
      type = "hdmi";
      description = "HDMI / DisplayPort";
      icon = "video-display";
      priority = 80;
    }
    {
      name = "dummy-lineout";
      element = "CD";
      type = "line";
      description = "Line Out";
      icon = "audio-card-analog";
      priority = 90;
    }
    {
      name = "dummy-spdif";
      element = "Mic";
      type = "spdif";
      description = "S/PDIF (Dock)";
      icon = "audio-card";
      priority = 50;
    }
  ];

  # An element-free path would be condensed away; binding one distinct control
  # (direction-try-other lets the ac97 capture-side control back an output path)
  # keeps each path as its own port.
  pathFile =
    p:
    pkgs.writeText "${p.name}.conf" ''
      [General]
      priority = ${toString p.priority}
      type = ${p.type}
      description = ${p.description}

      [Properties]
      device.icon_name = ${p.icon}

      [Element ${p.element}]
      volume = merge
      switch = mute
      direction-try-other = yes
      override-map.1 = all
      override-map.2 = all-left,all-right
    '';

  profileSet = pkgs.writeText "dummy-multiport.conf" ''
    [General]
    auto-profiles = yes

    [Mapping multiport]
    device-strings = hw:%f
    channel-map = left,right
    paths-output = ${lib.concatMapStringsSep " " (p: p.name) ports}
    priority = 100
    direction = output
  '';

  stockMixer = "${config.services.pipewire.package}/share/alsa-card-profile/mixer";

  # Stock ACP files symlinked in (so every other card keeps working and stock
  # `.include`s resolve), then our custom paths + profile-set copied on top.
  acpMixer = pkgs.runCommand "dummy-acp-mixer" { } ''
    mkdir -p $out/paths $out/profile-sets
    cp -rs ${stockMixer}/paths/.        $out/paths/
    cp -rs ${stockMixer}/profile-sets/. $out/profile-sets/
    ${lib.concatMapStringsSep "\n" (p: "cp ${pathFile p} $out/paths/${p.name}.conf") ports}
    cp ${profileSet} $out/profile-sets/dummy-multiport.conf
  '';

  acpEnv = {
    ACP_PATHS_DIR = "${acpMixer}/paths";
    ACP_PROFILES_DIR = "${acpMixer}/profile-sets";
  };
in
{
  boot.kernelModules = [ "snd-dummy" ];
  boot.extraModprobeConfig = "options snd-dummy enable=1 model=ac97";

  # acp_card_new() (which reads ACP_*_DIR) runs inside wireplumber here; pipewire
  # gets them too so the override holds wherever the device is instantiated.
  systemd.user.services.pipewire.environment = acpEnv;
  systemd.user.services.wireplumber.environment = acpEnv;

  services.pipewire.wireplumber.extraConfig."99-dummy-multiport" = {
    "monitor.alsa.rules" = [
      {
        matches = [ { "device.name" = "alsa_card.platform-snd_dummy.0"; } ];
        actions.update-props."device.profile-set" = "dummy-multiport.conf";
      }
    ];
  };
}
