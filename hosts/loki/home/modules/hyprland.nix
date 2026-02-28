{ config, pkgs, ... }:

{
  # ── Hypridle ──────────────────────────────────────────────────────────
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

  # ── Hyprland ──────────────────────────────────────────────────────────
  wayland.windowManager.hyprland.settings = {
    # ── Trackpad ────────────────────────────────────────────────────────
    input = {
      touchpad = {
        natural_scroll = true;
        disable_while_typing = false;
        clickfinger_behavior = true;
        tap-to-click = false;
      };
    };

    # ── Trackpoint ──────────────────────────────────────────────────────
    device = {
      name = "tpps/2-elan-trackpoint";
      sensitivity = "-0.4";
    };
    gesture = [
      "3, horizontal, workspace"
    ];

    # ── Monitors ────────────────────────────────────────────────────────
    monitor = [
        "eDP-1,highres,0x0,1.5"
        "DP-1,highres,auto-left,1"
        "HDMI-A-1,highres,auto-left,1"
    ];
    xwayland = {
      force_zero_scaling = true;
    };

    # ── Startup apps ────────────────────────────────────────────────────
    exec-once = [
      "steam -silent"
    ];
  };
}