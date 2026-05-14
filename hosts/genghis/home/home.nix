{ config, pkgs, ... }:

{
  imports = [
    ../../../home/profiles/base.nix
    ../../../home/profiles/desktop.nix
    ../../../home/profiles/x86/desktop.nix
    ./modules/hyprland.nix
    ./modules/waybar.nix
  ];
}
