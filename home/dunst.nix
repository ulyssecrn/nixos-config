{ config, pkgs, ... }:

{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        width = 500;
        height = 300;
        offset = "0x20";
        origin = "top-center";
        transparency = 10;
        frame_color = "#c0caf5";
        frame_width = 2;
        font = "Hack Nerd Font 11";
        corner_radius = 10;
        alignment = "center";
      };

      urgency_normal = {
        background = "#1a1b26";
        foreground = "#c0caf5";
        frame_color = "#c0caf5";
        timeout = 5;
      };

      urgency_low = {
        background = "#16161e";
        foreground = "#c0caf5";
        frame_color = "#c0caf5";
        timeout = 5;
      };

      urgency_critical = {
        background = "#292e42";
        foreground = "#db4b4b";
        frame_color = "#db4b4b";
      };
    };
  };
}