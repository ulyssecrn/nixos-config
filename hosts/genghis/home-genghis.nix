{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
  ];

  imports = [
    ../../home.nix
  ];
}