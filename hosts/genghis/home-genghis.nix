{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    steam-run
    davinci-resolve
    protonup-qt
  ];

  imports = [
    ../../home.nix
    ./hyprland.nix
  ];
}