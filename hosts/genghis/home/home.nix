{ config, pkgs, ... }:

{
  imports = [
    ../../../home/home.nix
    ../../../home/home_x86.nix
    ./modules/hyprland.nix
    ./modules/waybar.nix
  ];
}