{ config, pkgs, ... }:

{
  # ── Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    unityhub
  ];

  # ── Hardware ────────────────────────────────────────────────────────
  # Ledger wallet
  hardware.ledger.enable = true;

  # ── Virtualisation (GUI client + USB redirection) ───────────────────
  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
}
