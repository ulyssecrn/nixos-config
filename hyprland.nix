{ config, pkgs, ... }:

{
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    x11.enable = true;
    gtk.enable = true;
  };

  gtk.cursorTheme = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        grace = 5;
        hide_cursor = true;
        no_fade_in = false;
      };

      background = [
        {
          path = "/home/ucorne/Pictures/wallpapers/hong-kong2.jpg";
          blur_passes = 3;
          blur_size = 8;
        }
      ];

      input-field = [
        {
          size = "200, 50";
          position = "0, -400";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(202, 211, 245)";
          inner_color = "rgb(91, 96, 120)";
          outer_color = "rgb(24, 25, 38)";
          outline_thickness = 5;
          shadow_passes = 2;
          placeholder_text = "<i>Password...</i>";
        }
      ];
    };
  };
 
  services.hyprpaper = {
    enable = true;
    settings = {
      preload =
        [ "/home/ucorne/Pictures/wallpapers/hong-kong2.jpg" ];
      wallpaper = [
        ",/home/ucorne/Pictures/wallpapers/hong-kong2.jpg"
      ];
    };
  };

  wayland.windowManager.hyprland = {
    enable = true; # enable Hyprland
    xwayland.enable = true;
  };

  home.sessionVariables.NIXOS_OZONE_WL = "1";

  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    "$modsh" = "SUPER + SHIFT";
    "$modct" = "SUPER + CTRL";
    bind = [
      "$mod, return, exec, kitty"
      "$mod, B, exec, firefox"
      "$mod, C, exec, codium"
      "$mod, space, exec, rofi -show drun"
      "$mod, Q, killactive,"
      "$mod + CTRL + ALT, Q, exit,"
      "$mod, 1, workspace, 1"
      "$mod, 2, workspace, 2"
      "$mod, 3, workspace, 3"
      "$mod, 4, workspace, 4"
      "$mod, 5, workspace, 5"
      "$mod, 6, workspace, 6"
      "$mod, 7, workspace, 7"
      "$mod, 8, workspace, 8"
      "$modsh, 1, movetoworkspace, 1"
      "$modsh, 2, movetoworkspace, 2"
      "$modsh, 3, movetoworkspace, 3"
      "$modsh, 4, movetoworkspace, 4"
      "$modsh, 5, movetoworkspace, 5"
      "$modsh, 6, movetoworkspace, 6"
      "$modsh, 7, movetoworkspace, 7"
      "$modsh, 8, movetoworkspace, 8"
      "$modct, RIGHT, workspace, e+1"
      "$modct, LEFT, workspace, e-1"
      "$mod, escape, exec, ${pkgs.hyprlock}/bin/hyprlock"
    ];
    bindm = [
      "$mod,mouse:272, movewindow" # Move Window (mouse)
      "$mod,mouse:273, resizewindow" # Resize Window (mouse)
    ];
    bindl = [
      ",XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play-pause" # Play/Pause Song
      ",XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next" # Next Song
      ",XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous" # Previous Song
    ];
    bindle = [
      ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
      ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ",XF86MonBrightnessUp, exec, brightnessctl s 10%+"
      ",XF86MonBrightnessDown, exec, brightnessctl s 10%-"
    ];
    exec-once = [
        "systemctl --user start hyprpolkitagent"
        "waybar"
        "1password --silent"
        "hyprpaper"
        "dunst"
        "hypridle"
        "hyprctl setcursor Bibata-Modern-Ice 24"
    ];
    general = {
      resize_on_border = true;
      gaps_in = 5;
      gaps_out = 10;
      border_size = 2;
      layout = "dwindle";
    };
    decoration = {
      active_opacity = 0.99;
      inactive_opacity = 0.93;
      rounding = 0;
      shadow = {
        enabled = true;
        range = 4;
        render_power = 3;
      };
      blur = {
        enabled = true;
        size = 3;
      };
    };
    animations = {
      enabled = true;
    };
    windowrulev2 = [
      "idleinhibit fullscreen, class:^(*)$"
      "idleinhibit fullscreen, title:^(*)$"
      "idleinhibit fullscreen, fullscreen:1"
    ];
  };
}
