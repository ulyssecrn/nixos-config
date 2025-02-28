{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    pkgs.hyprlock
  ];
  
  services.hyprpaper = {
    enable = true;
    settings = {
      preload =
        [ "/home/ucorne/Pictures/wallpapers/hong-kong1.jpg" ];
      wallpaper = [
        "eDP-1,/home/ucorne/Pictures/wallpapers/hong-kong1.jpg"
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
    bind = [
      "$mod, return, exec, kitty"
      "$mod, B, exec, firefox"
      "$mod, space, exec, rofi -show drun"
      "$mod, Q, killactive,"
      "$mod, 1, workspace, 1"
      "$mod, 2, workspace, 2"
      "$mod, 3, workspace, 3"
      "$mod, 4, workspace, 4"
    ];
    input = {
      touchpad = {
        natural_scroll = true;
        clickfinger_behavior = true;
      };
    };
    bindm = [
      "$mod,mouse:272, movewindow" # Move Window (mouse)
      "$mod,mouse:273, resizewindow" # Resize Window (mouse)
    ];
    bindl = [
      ",XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play-pause" # Play/Pause Song
      ",XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next" # Next Song
      ",XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous" # Previous Song
      ",switch:Lid Switch, exec, ${pkgs.hyprlock}/bin/hyprlock" # Lock when closing Lid
    ];
    bindle = [
      ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
      ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ",XF86MonBrightnessUp, exec, brightnessctl s 10%+"
      ",XF86MonBrightnessDown, exec, brightnessctl s 10%-"
    ];
    monitor = [
        "eDP-1,highres,0x0,1.5"
        "HDMI-A-1,highres,-408x-1600,1"
    ];
    exec-once = [
        "systemctl --user start hyprpolkitagent"
        "waybar"
    ];
    gestures = { workspace_swipe = true; };
    general = {
      resize_on_border = true;
      gaps_in = 5;
      gaps_out = 10;
      border_size = 2;
      border_part_of_window = true;
      layout = "master";
    };
    decoration = {
      active_opacity = 1;
      inactive_opacity = 1;
      rounding = 5;
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
  };
}
