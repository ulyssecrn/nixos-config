{ config, lib, pkgs, ... }:

let
  c = config.lib.stylix.colors.withHashtag;
in
{
  # bg/fg colours come from Stylix's dunst target; override the font back to
  # the Hack Nerd Font (Stylix defaults dunst to sans-serif) and the frame to
  # base05 — the light border matching Hyprland. Geometry stays here.
  services.dunst = {
    enable = true;
    settings = {
      global = {
        width = 500;
        height = 300;
        offset = "0x20";
        origin = "top-center";
        transparency = 10;
        frame_width = 2;
        corner_radius = 10;
        alignment = "center";
        font = lib.mkForce "${config.stylix.fonts.monospace.name} 11";
        frame_color = lib.mkForce c.base05;
      };
      urgency_normal = {
        timeout = 5;
        frame_color = lib.mkForce c.base05;
      };
      urgency_low = {
        timeout = 5;
        frame_color = lib.mkForce c.base05;
      };
      urgency_critical.frame_color = lib.mkForce c.base08;
    };
  };
}
