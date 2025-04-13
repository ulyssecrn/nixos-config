{ config, pkgs, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
      };

      listener = [
        {
          timeout = 30;
          on-timeout = ''brightnessctl --device="kbd_backlight" set 0'';
          on-resume = ''brightnessctl --device="kbd_backlight" set 200'';
        }
        {
          timeout = 60;
          on-timeout = "hyprlock";
        }
        {
          timeout = 120;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  wayland.windowManager.hyprland.settings = {
    input = {
      touchpad = {
        natural_scroll = true;
        clickfinger_behavior = true;
      };
      kb_layout = "fr,us";
      kb_variant = "mac,";
      kb_options = "grp:shifts_toggle";
    };
    monitor = [
        "eDP-1,highres,0x0,1.5"
        "HDMI-A-1,highres,-912x-1600,1"
    ];
    gestures = { workspace_swipe = true; };
    xwayland = {
      force_zero_scaling = true;
    };
  };
}