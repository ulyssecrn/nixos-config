{ config, pkgs, ... }:

{
  imports = [
    ../../../home/home.nix
    ../../../home/home_x86.nix
    ./modules/hyprland-genghis.nix
    ./modules/waybar-genghis.nix
  ];
}