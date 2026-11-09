{ config, pkgs, ... }:

let
  # Toggle the HDMI projector (SANTAK S2-TEK) between mirror and off. It caps at
  # 1080p and mirroring needs matched modes, so eDP drops from its native
  # 2880x1800@1.5 to 1080p@1 while mirrored and is restored on toggle-off. State
  # is read from the live mirrorOf (HDMI is the last-listed output, so -A25 stays
  # inside its block) rather than a flag file, so it self-corrects across replug.
  mirror-projector = pkgs.writeShellScript "mirror-projector" ''
    if hyprctl monitors all | grep -A25 'Monitor HDMI-A-1' | grep -q 'mirrorOf: none'; then
      hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "0x0", scale = 1 })'
      hyprctl eval 'hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "auto", scale = 1, mirror = "eDP-1" })'
      ${pkgs.libnotify}/bin/notify-send -r 5560 "Projector" "Mirroring at 1080p"
    else
      hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "highres", position = "0x0", scale = 1.5 })'
      hyprctl eval 'hl.monitor({ output = "HDMI-A-1", mode = "highres", position = "auto-left", scale = 1 })'
      ${pkgs.libnotify}/bin/notify-send -r 5560 "Projector" "Mirror off — laptop native"
    fi
  '';

  # Backs waybar's coffee button. "awake" mutes every idle listener (what the
  # stock idle_inhibitor did); "display" still locks and blanks the screen but
  # skips the suspend. A runtime file rather than a wayland inhibitor because
  # hypridle has to tell the two modes apart.
  idle-mode = pkgs.writeShellScriptBin "idle-mode" ''
    state="$XDG_RUNTIME_DIR/idle-mode"
    mode=$(cat "$state" 2>/dev/null)
    case "$1" in
      toggle)
        if [ "$mode" = "$2" ]; then rm -f "$state"; else echo "$2" > "$state"; fi
        pkill -RTMIN+9 waybar
        ;;
      lock)
        [ "$mode" = awake ] || pidof hyprlock || hyprlock --grace 10
        ;;
      sleep)
        case "$mode" in
          awake) ;;
          display) hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' ;;
          *) systemctl suspend ;;
        esac
        ;;
      *)
        case "$mode" in
          awake) echo '{"text":"󰅶 ","class":"awake","tooltip":"Staying awake"}' ;;
          display) echo '{"text":"󰅶 ","class":"display","tooltip":"Display sleeps, laptop stays awake"}' ;;
          *) echo '{"text":"󰾪 ","tooltip":"Left: stay awake · Right: display sleeps only"}' ;;
        esac
        ;;
    esac
  '';
in
{
  home.packages = [ idle-mode ];

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
          timeout = 60;
          # idle-mode keeps lock_cmd's pidof guard: a leaked hyprlock makes `pidof`
          # succeed and silently suppresses every later lock, including on lid close
          on-timeout = "idle-mode lock";
        }
        {
          timeout = 120;
          on-timeout = "idle-mode sleep";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
        }
      ];
    };
  };

  # ── Hyprland ──────────────────────────────────────────────────────────
  wayland.windowManager.hyprland.settings = {
    config = {
      # ── Trackpad ──────────────────────────────────────────────────────
      input = {
        # EurKEY: plain US on every base key, accents behind right Alt
        # (AltGr+g é, +f è, +z à, +h ù, +c ç, +6 then a vowel for ^).
        kb_layout = "eu";
        touchpad = {
          natural_scroll = true;
          disable_while_typing = false;
          clickfinger_behavior = true;
          tap_to_click = false;
        };
      };
      xwayland = {
        force_zero_scaling = true;
      };
    };

    # ── Trackpoint ──────────────────────────────────────────────────────
    device = {
      name = "tpps/2-elan-trackpoint";
      sensitivity = -0.4;
    };
    gesture = [
      { fingers = 3; direction = "horizontal"; action = "workspace"; }
    ];

    # ── Monitors ────────────────────────────────────────────────────────
    monitor = [
      { output = "eDP-1"; mode = "highres"; position = "0x0"; scale = 1.5; }
      { output = "DP-1"; mode = "highres"; position = "auto-left"; scale = 1; }
      { output = "HDMI-A-1"; mode = "highres"; position = "auto-left"; scale = 1; }
    ];
  };

  # Super+P toggles the projector mirror (see mirror-projector above).
  wayland.windowManager.hyprland.extraConfig = ''
    hl.bind("SUPER + P", hl.dsp.exec_cmd("${mirror-projector}"))

    hl.on("hyprland.start", function()
      hl.exec_cmd("steam -silent")
    end)
  '';
}
