{ config, pkgs, ... }:

{
  # ── Hardware ────────────────────────────────────────────────────────
  # Ledger wallet
  hardware.ledger.enable = true;

  # ── Virtualisation (GUI client + USB redirection) ───────────────────
  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  # gtk2 is marked broken ahead of its removal before 27.05, but onlyoffice
  # (home/profiles/x86/desktop.nix) still puts it in its FHS env. Drop this once
  # onlyoffice stops depending on it, or before 27.05 lands, whichever is first.
  nixpkgs.config.problems.handlers."gtk+".broken = "warn";
}
