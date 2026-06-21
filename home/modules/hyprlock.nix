# home/modules/hyprlock.nix
{ config, pkgs, ... }:

let
  colors = config.lib.stylix.colors;
  wallpaper = "${config.stylix.image}";
in
{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
      };

      auth = {
        "fingerprint:enabled" = true;
      };

      background = [
        {
          path = wallpaper;
          blur_passes = 3;
          blur_size = 8;
        }
      ];

      input-field = [
        {
          size = "200, 50";
          position = "0, 200";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(${colors.base05})";
          inner_color = "rgb(${colors.base04})";
          outer_color = "rgb(${colors.base00})";
          outline_thickness = 5;
          shadow_passes = 2;
          placeholder_text = "<i>Password...</i>";
          halign = "center";
          valign = "bottom";
        }
      ];

      label = [
        # Time
        {
          monitor = "";
          text = "cmd[update:1000] echo \"<b><big> $(date +\"%H:%M:%S\") </big></b>\"";
          color = "rgb(${colors.base05})";
          font_size = 94;
          font_family = "Hack Nerd Font 10";
          position = "0, -200";
          halign = "center";
          valign = "top";
        }
        {
        # Date
          monitor = "";
          text = "cmd[update:18000000] echo \"<b> $(date +\"%A, %-d %B %Y\") </b>\"";
          color = "rgb(${colors.base05})";
          font_size = 34;
          font_family = "Hack Nerd Font 10";
          position = "0, -350";
          halign = "center";
          valign = "top";
        }
        # User
        {
          monitor = "";
          text = "  $USER";
          color = "rgb(${colors.base05})";
          font_size = 18;
          font_family = "Hack Nerd Font 10";
          position = "0, 100";
          halign = "center";
          valign = "bottom";
        }
      ];

      # Image
      image = [
        {
          monitor = "";
          path = wallpaper;
          size = 230;
          rounding = -1;
          border_size = 2;
          border_color = "rgb(${colors.base05})";
          rotate = 0;
          reload_time = -1;
          position = "0, 225";
          halign = "center";
          valign = "bottom";
        }
      ];

    };
  };
}