{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    brightnessctl
    xorg.xrdb
  ];

  imports = [
    ../../home.nix
    ./hyprland.nix
  ];

  # to fix fractionnal scaling on xwayland apps :
  home.file.".Xressources".text = ''
    Xft.dpi: 144
  '';
}