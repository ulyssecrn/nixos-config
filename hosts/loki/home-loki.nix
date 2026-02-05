{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    steam-run
    davinci-resolve
    protonup-qt
    spotify
    ledger-live-desktop
    zoom-us
    brightnessctl
    networkmanagerapplet
    slack
  ];

  programs.onlyoffice.enable = true;

  imports = [
    ../../home.nix
    ./hyprland.nix
    ./waybar.nix
  ];
}
