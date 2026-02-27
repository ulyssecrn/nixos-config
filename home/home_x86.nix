{ config, pkgs, ... }:

{
  # ── Packages ────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    steam-run
    davinci-resolve
    protonup-qt
    spotify
    ledger-live-desktop
    zoom-us
    slack
  ];

  programs.onlyoffice.enable = true;
}