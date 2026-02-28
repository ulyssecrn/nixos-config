# system/modules/plasma.nix
{ config, pkgs, lib, ... }:

{
  services.desktopManager.plasma6.enable = true;
  services.power-profiles-daemon.enable = false;

  # ── Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # KDE Utilities
    kdePackages.kcalc # Calculator
    kdePackages.ksystemlog # System log viewer
    kdiff3 # File/directory comparison tool
    kdePackages.partitionmanager # Disk and partition management
    hardinfo2 # System benchmarks and hardware info
    wayland-utils # Wayland diagnostic tools
    libsForQt5.qtstyleplugin-kvantum
    libsForQt5.qt5ct                 # qt5 theming
    kdePackages.qt6ct                # qt6 theming
  ];

  # ── Excludes ────────────────────────────────────────────────────────
  environment.plasma6.excludePackages = with pkgs; [
    kdePackages.elisa # Music player
    kdePackages.kdepim-runtime # Akonadi agents
    kdePackages.kmahjongg
    kdePackages.konversation # IRC client
    kdePackages.kpat # Solitaire
    kdePackages.ksudoku
    kdePackages.ktorrent
  ];

  # Keyring : using GNOME keyring
  security.pam.services.login.kwallet.enable = lib.mkForce false;
  programs.kde-pim.enable = false;

  # ── XDG Desktop portal ──────────────────────────────────────────────
  xdg.portal = {
    config = {
      kde.default = [ "kde" "gtk" "gnome" ];
      kde."org.freedesktop.portal.FileChooser" = [ "kde" ];
      kde."org.freedesktop.portal.OpenURI" = [ "kde" ];
    };
  };
}