{ config, pkgs, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        lock_cmd = "hyprlock";
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
    };
    monitor = [
        "eDP-1,highres,0x0,1.5"
        "HDMI-A-1,highres,-408x-1600,1"
    ];
    gestures = { workspace_swipe = true; };
    xwayland = {
      force_zero_scaling = true;
    };
  };
}