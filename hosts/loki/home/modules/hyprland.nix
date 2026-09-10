{ config, pkgs, ... }:

let
  # Toggle the HDMI projector (SANTAK S2-TEK) between mirror and off. It caps at
  # 1080p and mirroring needs matched modes, so eDP drops from its native
  # 2880x1800@1.5 to 1080p@1 while mirrored and is restored on toggle-off. State
  # is read from the live mirrorOf (HDMI is the last-listed output, so -A25 stays
  # inside its block) rather than a flag file, so it self-corrects across replug.
  mirror-projector = pkgs.writeShellScript "mirror-projector" ''
    if hyprctl monitors all | grep -A25 'Monitor HDMI-A-1' | grep -q 'mirrorOf: none'; then
      hyprctl keyword monitor "eDP-1,1920x1080@60,0x0,1"
      hyprctl keyword monitor "HDMI-A-1,1920x1080@60,auto,1,mirror,eDP-1"
      ${pkgs.libnotify}/bin/notify-send -r 5560 "Projector" "Mirroring at 1080p"
    else
      hyprctl keyword monitor "eDP-1,highres,0x0,1.5"
      hyprctl keyword monitor "HDMI-A-1,highres,auto-left,1"
      ${pkgs.libnotify}/bin/notify-send -r 5560 "Projector" "Mirror off — laptop native"
    fi
  '';
in
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
          # same pidof guard as lock_cmd: a leaked hyprlock makes `pidof` succeed
          # and silently suppresses every later lock, including on lid close
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

    # Super+P toggles the projector mirror (see mirror-projector above).
    bind = [
      "$mod, P, exec, ${mirror-projector}"
    ];

    # ── Startup apps ────────────────────────────────────────────────────
    exec-once = [
      "steam -silent"
    ];
  };
}
