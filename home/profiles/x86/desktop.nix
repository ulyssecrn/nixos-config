{ config, pkgs, ... }:

{
  # ── Packages ────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    steam-run
    protonup-qt
    spotify
    ledger-live-desktop
    zoom-us
    slack
  ];

  programs.onlyoffice.enable = true;
}
