{ config, lib, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  imports =
    [
      ./hardware-configuration.nix
      ../../system/common.nix
    ];

  # ── Boot & Kernel ───────────────────────────────────────────────────
  boot = {
    kernelParams = [
      "appledrm.show_notch=1"
    ];

    plymouth = {
      # Fix for pixelated splash screen on HiDPI displays
      extraConfig = ''
        DeviceScale=1
      '';
    };
  };

  # ── Networking ──────────────────────────────────────────────────────
  networking.hostName = "odin";

  # ── Locale & Input ──────────────────────────────────────────────────
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = ["en_US.UTF-8/UTF-8" "fr_FR.UTF-8/UTF-8"];
  services.xserver.xkb = {
    layout = "fr";
    model = "mac";
  };
  # use fr keyboard in console
  console = {
    earlySetup = true;
    useXkbConfig = true;
  };

  # ── Hardware ────────────────────────────────────────────────────────
  hardware.graphics = {
    enable = true;
  };

  hardware.asahi = {
    peripheralFirmwareDirectory = ./firmware;
    setupAsahiSound = true;
  };

  # Trackpad
  services.libinput.enable = true;

  # Prevent turning off with power key
  services.logind.settings.Login.HandlePowerKey = "suspend";

  # ── Overlays ────────────────────────────────────────────────────────
  nixpkgs.overlays = [ 
    # widevine-firefox for DRM content support
    (final: prev: {
      widevine-firefox = import ./pkgs/widevine-firefox.nix {
        stdenv = prev.stdenv;
        widevine-cdm = prev.widevine-cdm;
      };
    })
  ];

  # ── Environment ─────────────────────────────────────────────────────
  environment.sessionVariables.MOZ_GMP_PATH = "${pkgs.widevine-firefox}/gmp-widevinecdm/system-installed";

  # ── System ─────────────────────────────────────────────────────────
  system.stateVersion = "25.05";
}
