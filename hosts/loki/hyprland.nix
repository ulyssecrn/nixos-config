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
          on-resume = ''brightnessctl --device="kbd_backlight" set 180'';
        }
        {
          timeout = 60;
          on-timeout = "hyprlock --grace 10";
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
        "DP-1,highres,auto-left,1"
    ];
    gesture = [
      "3, horizontal, workspace"
    ];
    xwayland = {
      force_zero_scaling = true;
    };
    bindle = [
      ''ALT, XF86MonBrightnessUp, exec, brightnessctl --device="tpacpi::kbd_backlight" s 10%+''
      ''ALT, XF86MonBrightnessDown, exec, brightnessctl --device="tpacpi::kbd_backlight" s 10%-''
    ];
    exec-once = [
      "steam -silent"
      "nm-applet"
    ];
    debug = {
      disable_scale_checks = true;
    };
  };
}