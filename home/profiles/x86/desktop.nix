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
    bambu-studio
    (callPackage ../../pkgs/opensim-gui.nix { })
    (callPackage ../../pkgs/opensim-creator.nix { })
  ];

  programs.onlyoffice.enable = true;
}
