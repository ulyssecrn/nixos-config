{ config, pkgs, ... }:

let
  settings = import ../settings.nix;
in
{
  # ── Packages ────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    hyprpolkitagent
    hyprpicker
    hyprpaper
    hypridle
    hyprshot
  ];

  # ── XDG desktop portal ──────────────────────────────────────────────
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
    ];
    config = {
      hyprland = {
        default = [ "hyprland" "kde"];
        "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
      };
    };
  };
 
  # ── Hyprpaper ───────────────────────────────────────────────────────
  services.hyprpaper = {
    enable = true;
    settings = {
      wallpaper = {
        "monitor" = "";
        "path" = settings.wallpaperPath;
      };
      splash = false;
    };
  };

  # ── Hyprland ────────────────────────────────────────────────────────
  wayland.windowManager.hyprland = {
    enable = true; # enable Hyprland
    xwayland.enable = true;
    systemd.enable = false; # disabled for UWSM as per nixos wiki
  };

  home.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── Settings ────────────────────────────────────────────────────────
  wayland.windowManager.hyprland.settings = {
    # ── Keyboard bindings ───────────────────────────────────────────────
    "$mod" = "SUPER";
    "$modsh" = "SUPER + SHIFT";
    "$modct" = "SUPER + CTRL";
    bind = [
      "$mod, return, exec, kitty"
      "$mod, B, exec, brave"
      "$mod, C, exec, code"
      "$mod, F, exec, dolphin"
      "$mod, space, exec, rofi -show drun"

      "$mod, Q, killactive,"
      "$modsh, F, togglefloating,"
      "$modsh, Q, exec, rofi -show power-menu -modi power-menu:rofi-power-menu"

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

      # french azerty keyboard bindings
      "$mod, code:10, workspace, 1"
      "$mod, code:11, workspace, 2"
      "$mod, code:12, workspace, 3"
      "$mod, code:13, workspace, 4"
      "$mod, code:14, workspace, 5"
      "$mod, code:15, workspace, 6"
      "$mod, code:16, workspace, 7"
      "$mod, code:17, workspace, 8"
      "$modsh, code:10, movetoworkspace, 1"
      "$modsh, code:11, movetoworkspace, 2"
      "$modsh, code:12, movetoworkspace, 3"
      "$modsh, code:13, movetoworkspace, 4"
      "$modsh, code:14, movetoworkspace, 5"
      "$modsh, code:15, movetoworkspace, 6"
      "$modsh, code:16, movetoworkspace, 7"
      "$modsh, code:17, movetoworkspace, 8"
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
      ",XF86AudioMute, exec, bash -c 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED; then notify-send -r 5555 \"Volume\" \"Muted\"; else notify-send -r 5555 \"Volume\" \"Unmuted: $(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk \"{for(i=1;i<=NF;i++) if(\\$i ~ /^[0-9.]+$/) v=\\$i} END{percent=int(v*100); bar=\\\"\\\"; for(i=0;i<20;i++) bar=bar (i<percent/5?\\\"█\\\":\\\"─\\\"); printf \\\"%d%% %s\\\", percent, bar}\")\"; fi'"
      ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+; notify-send -r 5555 'Volume' \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{percent=int(\$2*100); bar=\"\"; for(i=0;i<20;i++) bar=bar (i<percent/5?\"█\":\"─\"); printf \"%d%% %s\", percent, bar}')\""
      ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-; notify-send -r 5555 'Volume' \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{percent=int(\$2*100); bar=\"\"; for(i=0;i<20;i++) bar=bar (i<percent/5?\"█\":\"─\"); printf \"%d%% %s\", percent, bar}')\""
      ",XF86MonBrightnessUp, exec, brightnessctl s 5%+; notify-send -r 5556 'Brightness' \"$(brightnessctl g | awk -v max=$(brightnessctl m) '{percent = int(\$1/max*100); bar = \"\"; for(i=0;i<20;i++) bar = bar (i < percent/5 ? \"█\" : \"─\"); printf \"%d%% %s\", percent, bar}')\""
      ",XF86MonBrightnessDown, exec, brightnessctl s 5%-; notify-send -r 5556 'Brightness' \"$(brightnessctl g | awk -v max=$(brightnessctl m) '{percent = int(\$1/max*100); bar = \"\"; for(i=0;i<20;i++) bar = bar (i < percent/5 ? \"█\" : \"─\"); printf \"%d%% %s\", percent, bar}')\""
    ];

    # ── Startup apps ────────────────────────────────────────────────────
    exec-once = [
        "systemctl --user start hyprpolkitagent"
        "waybar"
        "bitwarden"
        "hyprpaper"
        "dunst"
        "hypridle"
        "hyprctl setcursor Bibata-Modern-Ice 24"
        "wpctl set-volume @DEFAULT_AUDIO_SINK@ 15%"
        "nextcloud"
    ];

    # ── Environment ─────────────────────────────────────────────────────
    env = [
      "GSK_RENDERER,ngl"
      "ELECTRON_OZONE_PLATFORM_HINT,wayland"
      "env = GDK_BACKEND,wayland,x11,*"
      "env = QT_QPA_PLATFORM,wayland;xcb"
      "env = XDG_CURRENT_DESKTOP,Hyprland"
      "env = XDG_SESSION_TYPE,wayland"
      "env = XDG_SESSION_DESKTOP,Hyprland"
    ];

    # ── Appearance ──────────────────────────────────────────────────────
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

    # ── Window rules ────────────────────────────────────────────────────
    windowrule = [
      "match:title ^(Picture-in-Picture)$, float on" # firefox pip
      "match:title ^(Picture-in-Picture)$, pin on"
      "match:title ^(Picture in picture)$, float on" # chromium pip
      "match:title ^(Picture in picture)$, pin on "
      "match:class ^(nm-openconnect-auth-dialog), float on"
      "match:class ^(nm-openconnect-auth-dialog), pin on"
      "match:class ^(xdg-desktop-portal-gtk)$, float on"
      "match:class ^(xdg-desktop-portal-gtk)$, pin on"
      "match:class ^(org.gnome.Calculator)$, float on"
      "match:float 1, no_anim on"
    ];
  };
}
