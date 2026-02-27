{ config, pkgs, lazyvim, ... }:

{
  imports = [ lazyvim.homeManagerModules.default ];
  programs.lazyvim = {
    enable = true;
  };
}
