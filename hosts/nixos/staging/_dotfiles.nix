{ pkgs, ... }:
{
  # staging has no /home dataset and rolls back to rpool/nixos/root@blank on
  # every boot (see _disko.nix), so callum's home is empty on each boot. Re-apply
  # the dotfiles from scratch with chezmoi so a fresh boot always lands in a fully
  # configured session — this is the machine's whole purpose.
  systemd.services.apply-dotfiles = {
    description = "Apply callum's dotfiles with chezmoi";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    path = [
      pkgs.chezmoi
      pkgs.git # chezmoi shells out to git to clone the source repo
      # the dotfiles' chezmoi modify_/run_ scripts assume an interactive
      # userland (awk, sed, coreutils, …); expose the system profile so they run.
      "/run/current-system/sw"
    ];

    environment.HOME = "/home/callum";

    serviceConfig = {
      Type = "oneshot";
      User = "callum";
      # git.7sref may be slow or down; never wedge the boot indefinitely. greetd
      # only orders After this unit, so a failure here still lets login proceed.
      TimeoutStartSec = 30;
    };

    script = "chezmoi init --apply --force https://git.7sref/callum/dotfiles";
  };

  # Hold the auto-login session until the dotfiles are on disk so niri, fish,
  # ghostty, etc. come up already configured. This only orders greetd After the
  # apply (wants, not requires), so an unreachable git.7sref degrades to an
  # unconfigured session rather than blocking boot.
  systemd.services.greetd = {
    wants = [ "apply-dotfiles.service" ];
    after = [ "apply-dotfiles.service" ];
  };
}
