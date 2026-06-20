{ config, pkgs, ... }:

{
  # Colours + font come from Stylix (targets.dunst); geometry stays here.
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
      };
      urgency_normal.timeout = 5;
      urgency_low.timeout = 5;
    };
  };
}
