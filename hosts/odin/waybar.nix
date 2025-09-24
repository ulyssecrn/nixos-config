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
                font-size: 10pt;
                font-weight: bold;
                min-height: 0;
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
                margin-top: 8px;
              }
        #workspaces {
                padding-left: 4px;
                padding-right: 4px;
                border-radius: 10px;
                border: 2px solid rgb(61, 64, 74);
                background-color:rgba(22, 22, 30, 0.95);
              }
        #workspaces button {
                color: #c0caf5;
                background: none;
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
        #clock, #window {
                padding-left: 10px;
                padding-right: 10px;
                color: #c0caf5;
                background-color:rgba(22, 22, 30, 0.95);
                border: 2px solid rgb(61, 64, 74);
                border-radius: 10px;
               }
        #memory, #temperature, #cpu, #temperature, #backlight, #pulseaudio, #network, #battery, #idle_inhibitor, #tray, #bluetooth {
                padding-left: 5px;
                padding-right: 5px;
                color: #c0caf5;
                background-color:rgba(22, 22, 30, 0.95);
                border-top: 2px solid rgb(61, 64, 74);
                border-bottom: 2px solid rgb(61, 64, 74);
                border-left: none;
                border-right: none;
              }
        #memory, #idle_inhibitor, #bluetooth {
                padding-right: 10px;
                border-radius: 0px 10px 10px 0px;
                border-right: 2px solid rgb(61, 64, 74);
              }
        #custom-sep {
                padding-left: 0px;
                padding-right: 0px;
                background-color:rgba(0, 0, 0, 0);
                border: none;
              }
        #custom-notch {
                padding-left: 0px;
                padding-right: 0px;
                background-color:rgba(0, 0, 0, 0);
                border: none;
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
        #tray {
                padding-left: 10px;
                padding-right: 3px;
                border-radius: 10px 0px 0px 10px;
                border-left: 2px solid rgb(61, 64, 74);
              }
              menu {
                background: rgba(22, 22, 30, 0.95);
              }
        #cpu, #pulseaudio {
                padding-left: 10px;
                border-radius: 10px 0px 0px 10px;
                border-left: 2px solid rgb(61, 64, 74);
              }
    '';
    settings = [{
      "layer" = "top";
      "position" = "top";
      "height" = 40;
      modules-left = [
        "hyprland/workspaces"
        "custom/sep"
        "cpu"
        "memory"
        "custom/sep"
        "hyprland/window"
        "custom/sep"
      ];
      modules-center = [
        "custom/notch"
      ];
      modules-right = [
        "custom/sep"
        "tray"
        "idle_inhibitor"
        "custom/sep"
        "pulseaudio"
        "battery"
        "network"
        "bluetooth"
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
        "format" = "<span color='#7dcfff'>VOL</span> {volume}%";
        "format-muted" = "<span color='#7dcfff'>VOL</span> 0%";
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
        "format" = "<span color='#bb9af7'>MEM</span> {percentage:2}%";
        "states" = {
          "warning" = 95;
        };
        "on-click" = "kitty btop";
      };
      "cpu" = {
        "interval" = 1;
        "format" = "<span color='#7dcfff'>CPU</span> {usage:2}%";
        "on-click" = "kitty btop";
      };
      "battery" = {
        "interval" = 1;
        "states" = {
            "warning" = 20;
            "critical" = 10;
        };
        "format" = "<span color='#bb9af7'>BAT</span> {capacity:2}%";
      };
      "network" = {
        "format-disconnected" = "<span color='#e0af68'>OFFLINE</span>";
        "format-ethernet" = "<span color='#e0af68'>ETH</span> {ifname} {ipaddr}";
        "format-linked" = "<span color='#e0af68'>OFFLINE</span> {ifname}";
        "format-wifi" = "<span color='#e0af68'>WIFI</span> {essid}";
        "interval" = 1;
        "tooltip" = true;
        "tooltip-format" = "{ifname} {ipaddr} {signalStrength:2}%";
        "on-click" = "kitty sudo nmtui";
      };
      "bluetooth" = {
        "format" = "<span color='#9ece6a'>BT</span>";
        "format-off" = "<span color='#9ece6a'>BT</span> OFF";
        "format-disabled" = "<span color='#9ece6a'>BT</span> OFF";
        "format-on" = "<span color='#9ece6a'>BT</span> ON";
        "format-connected" = "<span color='#9ece6a'>BT</span> ON";
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
      "custom/notch" = {
        "format" = "                              "; # optimized for 1.55 scaling
      };
    }];
  };
}
