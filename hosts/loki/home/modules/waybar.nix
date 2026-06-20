{ config, pkgs, ... }:

let
  inherit (config.lib.stylix) colors;
  c = colors.withHashtag;  # "#rrggbb"
  rgba = base: a:
    "rgba(${colors."${base}-rgb-r"}, ${colors."${base}-rgb-g"}, ${colors."${base}-rgb-b"}, ${a})";
in
{
  # ── Waybar ──────────────────────────────────────────────────────────
  programs.waybar = {
    enable = true;
    systemd = {
      enable = false;
      targets = [ "graphical-session.target" ];
    };

    # ── Styling ─────────────────────────────────────────────────────────
    style = ''
              * {
                font-family: "Hack Nerd Font";
                font-size: 9pt;
                font-weight: bold;
                min-height: 20px;
                border-radius: 0px;
                  background-color: rgba(0, 0, 0, 0);
                transition-property: background-color;
                transition-duration: 0.5s;
              }
              window#waybar {
                background-color: transparent;
              }
              window > box {
                margin-left: 10px;
                margin-right: 10px;
                margin-top: 10px;
              }
        #workspaces {
                padding-left: 4px;
                padding-right: 4px;
                border-radius: 10px;
                border: 2px solid ${c.base03};
                background-color:${rgba "base01" "0.95"};
              }
        #workspaces button {
                color: ${c.base05};
                background: none;
                padding-left: 4px;
                padding-right: 4px;
              }
        #workspaces button.active {
                color: ${c.base05};
                background: none;
                padding-left: 4px;
                padding-right: 4px;
              }
        #workspaces button:hover {
                color: ${c.base05};
                background: none;
                border: none;
                box-shadow: none;
                text-shadow: none;
                padding-left: 4px;
                padding-right: 4px;
              }
              tooltip {
                background: ${c.base02};
              }
              tooltip label {
                color: ${c.base05};
              }
        #clock, #window {
                padding-left: 10px;
                padding-right: 10px;
                color: ${c.base05};
                background-color:${rgba "base01" "0.95"};
                border: 2px solid ${c.base03};
                border-radius: 10px;
               }
        #memory, #temperature, #cpu, #temperature, #backlight, #pulseaudio, #network, #network-speed, #battery, #custom-nvidia, #custom-nvidia-vram, #idle_inhibitor, #tray, #bluetooth, #custom-tailscale {
                padding-left: 5px;
                padding-right: 5px;
                color: ${c.base05};
                background-color:${rgba "base01" "0.95"};
                border-top: 2px solid ${c.base03};
                border-bottom: 2px solid ${c.base03};
                border-left: none;
                border-right: none;
              }
        #custom-nvidia-vram, #network-speed, #idle_inhibitor, #network {
                padding-right: 10px;
                border-radius: 0px 10px 10px 0px;
                border-right: 2px solid ${c.base03};
              }
        #custom-sep {
                padding-left: 0px;
                padding-right: 0px;
                background-color:rgba(0, 0, 0, 0);
                border: none;
              }
        #battery.charging {
                color: ${c.base0B};
              }
        #battery.warning {
                color: ${c.base0A};
              }
        #battery.critical {
                color: ${c.base08};
              }
        #tray {
                padding-left: 10px;
                padding-right: 3px;
                border-radius: 10px 0px 0px 10px;
                border-left: 2px solid ${c.base03};
              }
              menu {
                background: ${rgba "base01" "0.95"};
              }
        #cpu, #pulseaudio, #custom-nvidia {
                padding-left: 10px;
                border-radius: 10px 0px 0px 10px;
                border-left: 2px solid ${c.base03};
              }
    '';

    # ── Settings ────────────────────────────────────────────────────────
    settings = [{
      "layer" = "top";
      "position" = "top";
      modules-left = [
        "hyprland/workspaces"
        "custom/sep"
        "cpu"
        "memory"
        "temperature"
        "network#speed"
        "custom/sep"
        "custom/nvidia"
        "custom/nvidia-vram"
        "custom/sep"
      ];
      modules-center = [
        "hyprland/window"
      ];
      modules-right = [
        "custom/sep"
        "tray"
        "idle_inhibitor"
        "custom/sep"
        "pulseaudio"
        "battery"
        "custom/tailscale"
        "network"
        "custom/sep"
        "clock"
      ];
      "hyprland/workspaces" = {
        "persistent-workspaces" = {
          "*" = 5;
        };
        "format" = "{icon}";
        "format-icons" = {
          "default" = "";
          "active" = "";
        };
      };
      "pulseaudio" = {
        "scroll-step" = 1;
        "format" = "<span color='${c.base0C}'>VOL</span> {volume}%";
        "format-muted" = "<span color='${c.base0C}'>VOL</span> 0%";
        "on-click" = "pavucontrol";
        "tooltip" = false;
      };
      "clock" = {
        "interval" = 1;
        "format" = "{:%H:%M:%S  %d-%m-%Y}";
        "on-click" = "rofi -show power-menu -modi power-menu:rofi-power-menu";
      };
      "memory" = {
        "interval" = 1;
        "format" = "<span color='${c.base0E}'>MEM</span> {percentage:2}%";
        "states" = {
          "warning" = 95;
        };
        "on-click" = "kitty btop";
      };
      "cpu" = {
        "interval" = 1;
        "format" = "<span color='${c.base0C}'>CPU</span> {usage:2}%";
        "on-click" = "kitty btop";
      };
      "temperature" = {
        "interval" = 1;
        "hwmon-path-abs" = "/sys/devices/platform/coretemp.0/hwmon";
        "input-filename" = "temp1_input";
        "critical-threshold" = 85;
        "format" = "<span color='${c.base0B}'>TEMP</span> {temperatureC:2}°C";
        "format-critical" = "<span color='${c.base08}'>TEMP</span> {temperatureC:2}°C";
        "on-click" = "kitty btop";
      };
      "network#speed" = {
        "interval" = 2;
        "format" = "<span color='${c.base0A}'>NET</span> ↓{bandwidthDownBytes:>10} ↑{bandwidthUpBytes:>10}";
        "format-disconnected" = "<span color='${c.base0B}'>NET</span> ↓      0 B/s ↑      0 B/s";
        "tooltip-format" = "{ifname}  ↓ {bandwidthDownBytes}/s   ↑ {bandwidthUpBytes}/s";
      };
      "battery" = {
        "interval" = 1;
        "states" = {
            "warning" = 20;
            "critical" = 10;
        };
        "format" = "<span color='${c.base0E}'>BAT</span> {capacity:2}%";
      };
      "network" = {
        "format-disconnected" = "<span color='${c.base0A}'>OFFLINE</span>";
        "format-ethernet" = "<span color='${c.base0A}'>ETH</span> {ifname} {ipaddr}";
        "format-linked" = "<span color='${c.base0A}'>OFFLINE</span> {ifname}";
        "format-wifi" = "<span color='${c.base0A}'>WIFI</span> {essid}";
        "interval" = 1;
        "tooltip" = true;
        "tooltip-format" = "{ifname} {ipaddr} {signalStrength:2}%";
        "on-click" = "kitty sudo nmtui";
      };
      "bluetooth" = {
        "format" = "<span color='${c.base0B}'>BT</span>";
        "format-off" = "<span color='${c.base0B}'>BT</span> OFF";
        "format-disabled" = "<span color='${c.base0B}'>BT</span> OFF";
        "format-on" = "<span color='${c.base0B}'>BT</span> ON";
        "format-connected" = "<span color='${c.base0B}'>BT</span> ON";
        "on-click" = "blueman-manager";
      };
      "tray" = {
        "icon-size" = 15;
        "spacing" = 5;
      };
      "idle_inhibitor" = {
          "format" = "{icon}";
          "format-icons" = {
              "activated"= "󰅶 ";
              "deactivated"= "󰾪 ";
          };
      };
      "custom/sep" = {
        "format" = " ";
      };
      "custom/nvidia" = {
        "exec" = ''
        nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{ printf "%2s\n", $1 }'
        '';
        "format" = "<span color='${c.base0A}'>GPU</span> {}%";
        "interval" = 1;
        "on-click" = "kitty watch -n 1 nvidia-smi";
      };
      "custom/nvidia-vram" = {
        "exec" = ''
          bash -c '
          free=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
          total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)
          ratio=$(awk -v a="$free" -v b="$total" "BEGIN{ printf( \"%2.f\", 100 * a / b) }")
          echo $ratio'
          '';
        "format" = "<span color='${c.base0B}'>VRAM</span> {}%";
        "interval" = 1;
        "on-click" = "kitty watch -n 1 nvidia-smi";
      };
      "custom/tailscale" = {
        "exec" = ''
          bash -c '
          exit_node=$(tailscale status 2>/dev/null | grep -v "offers exit node" | grep "exit node" | awk "{print \$2}")
          if [ -z "$exit_node" ]; then
            echo "none"
          else
            echo "$exit_node"
          fi'
        '';
        "format" = "<span color='${c.base0B}'>VPN</span> {}";
        "interval" = 5;
        "tooltip" = true;
        "tooltip-format" = "Click to change exit node";
        "on-click" = ''
          bash -c '
          nodes=$(tailscale exit-node list 2>/dev/null | tail -n +2 | grep -v "^#" | grep -v "HOSTNAME" | awk "{print \$2}" | sed "s/\..*//" | grep -v "^$")
          options=$(echo -e "None\n$nodes")
          chosen=$(echo "$options" | rofi -dmenu -p "Exit Node" -theme-str "window { width: 300px; }")
          if [ "$chosen" = "None" ]; then
            tailscale set --exit-node=
          elif [ -n "$chosen" ]; then
            tailscale set --exit-node="$chosen"
          fi'
        '';
      };
    }];
  };
}
