{ config, pkgs, ... }:

{
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    x11.enable = true;
    gtk.enable = true;
  };

  gtk = {
    enable = true;
    gtk3.extraConfig.gtk-decoration-layout = "menu:";
    theme = {
      name = "Tokyonight-Dark";
      package = pkgs.tokyo-night-gtk;
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
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
          position = "0, 200";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(202, 211, 245)";
          inner_color = "rgb(91, 96, 120)";
          outer_color = "rgb(24, 25, 38)";
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
          color = "$color15";
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
          color = "$color12";
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
          color = "$color12";
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
          path = "$HOME/Pictures/wallpapers/hong-kong2.jpg";
          size = 230;
          rounding = -1;
          border_size = 2;
          border_color = "$color11";
          rotate = 0;
          reload_time = -1;
          position = "0, 225";
          halign = "center";
          valign = "bottom";
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
      "$mod, C, exec, code"
      "$mod, space, exec, rofi -show drun"
      "$mod, Q, killactive,"
      "$mod, F, togglefloating,"
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
      "$mod, S, exec, hyprshot -m output -f png -o /home/ucorne/Pictures/screenshots"
      "$modsh, S, exec, hyprshot -m window -f png -o /home/ucorne/Pictures/screenshots"
      "$modct, S, exec, hyprshot -m region -f png -o /home/ucorne/Pictures/screenshots"
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
      ",XF86AudioMute, exec, bash -c 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED; then notify-send -r 5555 \"Volume\" \"Muted\"; else notify-send -r 5555 \"Volume\" \"Unmuted: $(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk \"{for(i=1;i<=NF;i++) if(\\$i ~ /^[0-9.]+$/) v=\\$i} END{print int(v*100)}\")%\"; fi'"
      ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+; notify-send -r 5555 'Volume' \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int(\$2*100)}')%\""
      ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-; notify-send -r 5555 'Volume' \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int(\$2*100)}')%\""
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
        "wpctl set-volume @DEFAULT_AUDIO_SINK@ 15%"
        "nextcloud"
    ];
    env = [
      "GSK_RENDERER,ngl"
      "ELECTRON_OZONE_PLATFORM_HINT,wayland"
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
      rounding = 10;
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
      "float, title:^(Picture-in-Picture)$"
      "pin, title:^(Picture-in-Picture)$"
      "noanim,floating:1"
      "unset, title:^(.*Godot.*)$"
      "tile, title:^(.*Godot.*)$"
    ];
  };
}
