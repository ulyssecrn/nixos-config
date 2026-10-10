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
    anydesk
    (callPackage ../../pkgs/opensim-gui.nix { })
  ];

  programs.onlyoffice.enable = true;
}
