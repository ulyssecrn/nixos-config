{ config, pkgs, ... }:

{
  imports = [
    ../../../home/profiles/base.nix
    ../../../home/modules/herdr.nix
  ];
}
