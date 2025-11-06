{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    steam-run
    davinci-resolve
    protonup-qt
    ledger-live-desktop
  ];

  imports = [
    ../../home.nix
    ./hyprland.nix
    ./waybar.nix
  ];
}