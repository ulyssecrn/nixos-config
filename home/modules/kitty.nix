{ config, pkgs, ... }:

{
  # Colours + font now come from Stylix (targets.kitty). Only non-theme
  # settings live here.
  programs.kitty = {
    enable = true;
    settings = {
      window_margin_width = "3 5 3";
      confirm_os_window_close = "0";
      copy_on_select = "yes";   # selecting text copies it to the clipboard

    };
  };
}
