# home/modules/btop.nix
{ config, pkgs, lib, ... }:

{
  programs.btop = {
    enable = true;
    settings = {
      # loki/odin/atilla/genghis pull in the Stylix btop target (home/modules/
      # stylix.nix), which overrides this to the generated "stylix" theme.
      # hannibal has no Stylix (stable HM incompatibility — see stylix.nix), so
      # it keeps btop's bundled tokyo-night through the mkDefault. The mkDefault
      # is load-bearing: without it, the non-Stylix host would be themeless.
      color_theme = lib.mkDefault "tokyo-night";
      theme_background = false;   # transparent bg; Stylix leaves this alone at opacity 1.0
    };
  };
}
