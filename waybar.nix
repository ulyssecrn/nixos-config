{ config, pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    systemd = {
      enable = false;
      target = "graphical-session.target";
    };
    style = ''
              * {
                font-family: "Hack Nerd Font";
                font-size: 11pt;
                font-weight: bold;
                border-radius: 0px;
                transition-property: background-color;
                transition-duration: 0.5s;
              }
              @keyframes blink_red {
                to {
                  background-color: rgb(242, 143, 173);
                  color: rgb(26, 24, 38);
                }
              }
              .warning, .critical, .urgent {
                animation-name: blink_red;
                animation-duration: 1s;
                animation-timing-function: linear;
                animation-iteration-count: infinite;
                animation-direction: alternate;
              }
              window#waybar {
                background-color: transparent;
              }
              window > box {
                margin-left: 0px;
                margin-right: 0px;
                margin-top: 0px;
                background-color: #16161e;
                padding: 0px;
                padding-left: 5px;
              }
        #workspaces {
                padding-left: 4px;
                padding-right: 4px;
              }
        #workspaces button {
                color: #c0caf5;
                padding-left: 4px;
                padding-right: 4px;
              }
        #workspaces button.active {
                color: #c0caf5;
                background: none;
                padding-left: 4px;
                padding-right: 4px;
              }
        #workspaces button:hover {
                color: #c0caf5;
                background: none;
                border: none;
                box-shadow: none;
                text-shadow: none;
                padding-left: 4px;
                padding-right: 4px;
              }
              tooltip {
                background: rgb(48, 45, 65);
              }
              tooltip label {
                color: rgb(217, 224, 238);
              }
        #mode, #clock, #memory, #temperature, #cpu, #temperature, #backlight, #pulseaudio, #network, #battery, #custom-nvidia, #custom-nvidia-vram {
                padding-left: 5px;
                padding-right: 5px;
                color: #c0caf5;
              }
        #memory {
                color: #c0caf5;
              }
        #cpu {
                color: #c0caf5;
              }
        #battery {
                color: #c0caf5;
              }
        #battery.charging {
                color: #9ece6a;
              }
        #battery.warning {
                color: #e0af68;
              }
        #battery.critical {
                color: #f7768e;
              }
        #clock {
                color: #c0caf5;
              }
        #temperature {
                color: rgb(150, 205, 251);
              }
        #backlight {
                color: #c0caf5;
              }
        #pulseaudio {
                color: #c0caf5;
              }
        #network {
                color: #c0caf5;
              }
        #tray {
                padding-right: 8px;
                padding-left: 10px;
              }
    '';
    settings = [{
      "layer" = "top";
      "position" = "top";
      modules-left = [
        "hyprland/workspaces"
      ];
      modules-center = [
        "clock"
      ];
      modules-right = [
        "tray"
        "idle_inhibitor"
        "custom/sep"
        "pulseaudio"
        "backlight"
        "battery"
        "network"
        "custom/sep"
        "cpu"
        "memory"
        "custom/nvidia"
        "custom/nvidia-vram"
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
        "format" = "{icon} {volume:2}%";
        "format-muted" = "󰖁 Muted";
        "format-icons" = {
          "default" = [ "" "" "" ];
        };
        "on-click" = "pamixer -t";
        "tooltip" = false;
      };
      "clock" = {
        "interval" = 1;
        "format" = "{:%H:%M:%S  %d-%m-%Y}";
      };
      "memory" = {
        "interval" = 1;
        "format" = "M {percentage:2}%";
        "states" = {
          "warning" = 95;
        };
        "on-click" = "kitty btop";
      };
      "cpu" = {
        "interval" = 1;
        "format" = "C {usage:2}%";
        "on-click" = "kitty btop";
      };
      "battery" = {
        "interval" = 1;
        "states" = {
            "warning" = 30;
            "critical" = 15;
        };
        "format" = "{icon} {capacity:2}%";
        "format-charging" = " {icon} {capacity:2}%";
        "format-icons" = ["󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
      };
      "backlight" = {
        "interval" = 1;
        "format" = " {percent:2}%";
      };
      "network" = {
        "format-disconnected" = "󰯡 ";
        "format-ethernet" = " ";
        "format-linked" = "󰖪 ";
        "format-wifi" = "󰖩 ";
        "interval" = 1;
        "tooltip" = false;
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
        "format" = "||";
      };
      "custom/nvidia" = {
        "exec" = ''
        nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{ printf "%2s\n", $1 }'
        '';
        "format" = "G {}%";
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
        "format" = "V {}%";
        "interval" = 1;
        "on-click" = "kitty watch -n 1 nvidia-smi";
      };
    }];
  };
}
