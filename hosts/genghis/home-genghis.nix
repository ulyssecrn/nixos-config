{ config, pkgs, ... }:

{
  imports = [
    ../../home/home.nix
    ../../home/home_x86.nix
    ./hyprland.nix
    ./waybar.nix
  ];
}