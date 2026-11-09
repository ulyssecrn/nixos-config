{ config, pkgs, ... }:

{
  # ── Hypridle ──────────────────────────────────────────────────────────
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
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
          # see loki's hyprland.nix — guard against a leaked hyprlock
          on-timeout = "pidof hyprlock || hyprlock --grace 10";
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
    config = {
      # ── Trackpad & keyboard ───────────────────────────────────────────
      input = {
        touchpad = {
          natural_scroll = true;
          clickfinger_behavior = true;
        };
        kb_layout = "fr,us";
        kb_variant = "mac,";
        kb_options = "grp:shifts_toggle";
        resolve_binds_by_sym = true;
      };
      xwayland = {
        force_zero_scaling = true;
      };
      debug = {
        disable_scale_checks = true;
      };
    };
    gesture = [
      { fingers = 3; direction = "horizontal"; action = "workspace"; }
    ];

    # ── Monitors ────────────────────────────────────────────────────────
    monitor = [
      { output = "eDP-1"; mode = "highres"; position = "0x0"; scale = 1.55; }
      { output = "HDMI-A-1"; mode = "highres"; position = "auto-left"; scale = 1; }
    ];
  };

  # ── Keyboard bindings ─────────────────────────────────────────────────
  wayland.windowManager.hyprland.extraConfig = ''
    hl.bind("ALT + XF86MonBrightnessUp", hl.dsp.exec_cmd('brightnessctl --device="kbd_backlight" s 10%+'), { locked = true, repeating = true })
    hl.bind("ALT + XF86MonBrightnessDown", hl.dsp.exec_cmd('brightnessctl --device="kbd_backlight" s 10%-'), { locked = true, repeating = true })
  '';
}
