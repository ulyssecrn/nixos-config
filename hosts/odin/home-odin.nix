{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    brightnessctl
    xorg.xrdb
    widevine-firefox # for DRM content in firefox
  ];

  imports = [
    ../../home.nix
    ./hyprland.nix
  ];

  # to fix fractionnal scaling on xwayland apps : BROKEN
  #home.file.".Xressources".text = ''
  #  Xft.dpi: 144
  #'';
}