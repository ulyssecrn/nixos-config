{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    steam-run
    davinci-resolve
  ];

  imports = [
    ../../home.nix
    ./hyprland.nix
  ];
}