{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    brightnessctl
    xorg.xrdb
    widevine-firefox # for DRM content in firefox
    widevine-cdm # for DRM content in chromium TODO: make it work
  ];

  imports = [
    ../../home/home.nix
    ./hyprland.nix
    ./waybar.nix
  ];

  # to fix fractionnal scaling on xwayland apps : BROKEN
  #home.file.".Xressources".text = ''
  #  Xft.dpi: 144
  #'';
}