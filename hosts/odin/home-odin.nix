{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    brightnessctl
  ];

  imports = [
    ../../home.nix
  ];

  # to fix fractionnal scaling on xwayland apps :
  home.file.".Xressources".text = ''
    Xft.dpi: 144
  '';
}