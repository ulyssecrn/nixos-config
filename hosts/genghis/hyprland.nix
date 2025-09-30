{ config, pkgs, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        lock_cmd = "hyprlock";
      };

      listener = [
        {
          timeout = 300;
          on-timeout = "hyprlock --grace 10";
        }
        {
          timeout = 600;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "steam -silent"
    ];    
    env = [
      "env = GBM_BACKEND,nvidia-drm"
      "env = __GLX_VENDOR_LIBRARY_NAME,nvidia"
      "env = LIBVA_DRIVER_NAME,nvidia"
    ];
  };
}