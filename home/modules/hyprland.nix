{ config, pkgs, ... }:

let
  colors = config.lib.stylix.colors;

  # Volume/brightness/mic keys pop a dunst notification with a 20-cell bar; the
  # fixed -r ids make repeated presses replace the previous popup.
  osd = pkgs.writeShellScript "osd" ''
    bar() { awk -v p="$1" 'BEGIN { b = ""; for (i = 0; i < 20; i++) b = b (i < p / 5 ? "█" : "─"); printf "%d%% %s", p, b }'; }
    sink_pct() { wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{ print int($2 * 100) }'; }
    muted() { wpctl get-volume "$1" | grep -q MUTED; }

    case "$1" in
      volume-up | volume-down)
        if [ "$1" = volume-up ]; then
          wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
        else
          wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        fi
        notify-send -r 5555 Volume "$(bar "$(sink_pct)")"
        ;;
      volume-mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        if muted @DEFAULT_AUDIO_SINK@; then
          notify-send -r 5555 Volume Muted
        else
          notify-send -r 5555 Volume "Unmuted: $(bar "$(sink_pct)")"
        fi
        ;;
      mic-mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        if muted @DEFAULT_AUDIO_SOURCE@; then
          notify-send -r 5557 Microphone Muted
        else
          notify-send -r 5557 Microphone Unmuted
        fi
        ;;
      brightness-up | brightness-down)
        if [ "$1" = brightness-up ]; then brightnessctl s 5%+; else brightnessctl s 5%-; fi
        notify-send -r 5556 Brightness "$(bar "$(( $(brightnessctl g) * 100 / $(brightnessctl m) ))")"
        ;;
    esac
  '';

  screenshot = mode:
    ''hyprshot -m ${mode} -f "screenshot_$(date +%Y-%m-%d_%H-%M-%S).png" -o ${config.home.homeDirectory}/Pictures/screenshots'';

  floatPin = match: { inherit match; float = true; pin = true; };
  floatCenter = match: { inherit match; float = true; center = true; };
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
  # Daemon only; wallpaper settings come from stylix.targets.hyprpaper.
  services.hyprpaper.enable = true;

  # ── Hyprland ────────────────────────────────────────────────────────
  wayland.windowManager.hyprland = {
    enable = true; # enable Hyprland
    xwayland.enable = true;
    systemd.enable = false; # disabled for UWSM as per nixos wiki
    # Hyprland 0.57 only reads hyprland.lua; a leftover hyprland.conf is ignored.
    configType = "lua";
  };

  home.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── Settings ────────────────────────────────────────────────────────
  # Each attribute renders as an hl.<name>(...) call; host modules merge into
  # `config` and append to the lists.
  wayland.windowManager.hyprland.settings = {
    config = {
      input = {
        repeat_delay = 300;  # ms before a held key starts repeating (default 600)
        repeat_rate = 75;    # repeats per second while held (default 25)
      };

      general = {
        resize_on_border = true;
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        col = {
          active_border = "rgb(${colors.base05})";
          inactive_border = "rgb(${colors.base03})";
        };
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
    };

    # ── Window rules ────────────────────────────────────────────────────
    window_rule = [
      # Apps that ask to start maximized (kitty restoring a saved "maximized"
      # window-state, LibreOffice) otherwise map fullscreen-ish instead of tiling.
      { match.class = ".*"; suppress_event = "maximize"; }
      (floatPin { title = "^(Picture-in-Picture)$"; }) # firefox pip
      (floatPin { title = "^(Picture in picture)$"; }) # chromium pip
      (floatPin { title = "^(Bitwarden)$"; })
      # Brave's Bitwarden extension popup opens titled _crx_<id>, so the title
      # rule above misses it at map time; the class carries the extension id.
      (floatCenter { class = "^(brave-nngceckbapebfimnlniiiahkandclblb-Default)$"; })
      (floatPin { class = "^(nm-openconnect-auth-dialog)"; })
      (floatPin { class = "^(xdg-desktop-portal-gtk)$"; })
      { match.class = "^(org.gnome.Calculator)$"; float = true; }
      (floatCenter { class = "^(Matplotlib)$"; })
      (floatCenter { class = "^(localsend_app)$"; })
      { match.float = true; no_anim = true; }
    ];
  };

  wayland.windowManager.hyprland.extraConfig = ''
    -- ── Environment ──────────────────────────────────────────────────────
    -- XDG_CURRENT_DESKTOP / XDG_SESSION_TYPE / XDG_SESSION_DESKTOP are set by UWSM.
    hl.env("GSK_RENDERER", "ngl")
    hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
    hl.env("GDK_BACKEND", "wayland,x11,*")
    hl.env("QT_QPA_PLATFORM", "wayland;xcb")
    -- Bitwarden SSH agent for GUI apps. desktop.nix only exports SSH_AUTH_SOCK
    -- in interactive zsh, so apps Hyprland launches directly (VSCode Remote-SSH,
    -- etc.) get an empty one and our `IdentityAgent SSH_AUTH_SOCK` resolves to
    -- no agent — ssh then finds no key though the terminal connects fine.
    -- Exporting it at the session level fixes every GUI client at once.
    hl.env("SSH_AUTH_SOCK", "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock")

    -- ── Keyboard bindings ────────────────────────────────────────────────
    local mod = "SUPER"
    local modsh = "SUPER + SHIFT"
    local modct = "SUPER + CTRL"
    local exec = hl.dsp.exec_cmd
    local locked = { locked = true }
    local lockedRepeat = { locked = true, repeating = true }

    hl.bind(mod .. " + return", exec("kitty"))
    hl.bind(mod .. " + B", exec("brave"))
    hl.bind(mod .. " + C", exec("code"))
    hl.bind(mod .. " + N", exec("kitty nvim"))
    hl.bind(mod .. " + F", exec("dolphin"))
    hl.bind(mod .. " + space", exec("rofi -show drun"))

    hl.bind(mod .. " + Q", hl.dsp.window.close())
    hl.bind(modsh .. " + F", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(modsh .. " + Q", exec("rofi -show power-menu -modi power-menu:rofi-power-menu"))

    -- code:10..17 are the number-row keycodes, so workspaces follow the
    -- physical key on French AZERTY too.
    for i = 1, 8 do
      for _, key in ipairs({ tostring(i), "code:" .. (i + 9) }) do
        hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
        hl.bind(modsh .. " + " .. key, hl.dsp.window.move({ workspace = i, follow = true }))
      end
    end

    hl.bind(modct .. " + RIGHT", hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(modct .. " + LEFT", hl.dsp.focus({ workspace = "e-1" }))

    hl.bind(mod .. " + escape", exec("${pkgs.hyprlock}/bin/hyprlock"))

    hl.bind(mod .. " + S", exec([[${screenshot "output"}]]))
    hl.bind(modsh .. " + S", exec([[${screenshot "window"}]]))
    hl.bind(modct .. " + S", exec([[${screenshot "region"}]]))

    hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    hl.bind("XF86AudioPlay", exec("${pkgs.playerctl}/bin/playerctl play-pause"), locked)
    hl.bind("XF86AudioNext", exec("${pkgs.playerctl}/bin/playerctl next"), locked)
    hl.bind("XF86AudioPrev", exec("${pkgs.playerctl}/bin/playerctl previous"), locked)
    -- Mic mute (loki's F4). The key has always emitted KEY_MICMUTE cleanly, it
    -- just had nothing listening for it.
    hl.bind("XF86AudioMicMute", exec("${osd} mic-mute"), locked)

    hl.bind("XF86AudioMute", exec("${osd} volume-mute"), lockedRepeat)
    hl.bind("XF86AudioRaiseVolume", exec("${osd} volume-up"), lockedRepeat)
    hl.bind("XF86AudioLowerVolume", exec("${osd} volume-down"), lockedRepeat)
    hl.bind("XF86MonBrightnessUp", exec("${osd} brightness-up"), lockedRepeat)
    hl.bind("XF86MonBrightnessDown", exec("${osd} brightness-down"), lockedRepeat)

    -- ── Startup apps ─────────────────────────────────────────────────────
    hl.on("hyprland.start", function()
      hl.exec_cmd("systemctl --user start hyprpolkitagent")
      hl.exec_cmd("waybar")
      hl.exec_cmd("bitwarden")
      hl.exec_cmd("hyprpaper")
      hl.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 15%")
      hl.exec_cmd("nextcloud")
      hl.exec_cmd("nm-applet")
      hl.exec_cmd("localsend_app --hidden")
    end)
  '';
}
