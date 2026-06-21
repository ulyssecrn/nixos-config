# home/modules/btop.nix
{ config, pkgs, ... }:

{
  programs.btop = {
    enable = true;
    settings = {
      # color_theme comes from Stylix (targets.btop → generated "stylix" theme).
      theme_background = false;   # transparent bg; Stylix leaves this alone at opacity 1.0
    };
  };
}
