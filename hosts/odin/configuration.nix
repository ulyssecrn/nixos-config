{ config, lib, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  imports =
    [
      ./hardware-configuration.nix
      ../../system/profiles/base.nix
      ../../system/profiles/desktop.nix
    ];

  # ── Boot & Kernel ───────────────────────────────────────────────────
  boot = {
    loader.systemd-boot.enable = true;
    loader.systemd-boot.configurationLimit = 10;
    loader.efi.canTouchEfiVariables = true;

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
    enable = true;
    setupAsahiSound = true;
    # The peripheral firmware (wifi, webcam, ALS) is non-redistributable, so it
    # can't be vendored into a public repo. Its default source, /boot/vendorfw,
    # only exists on odin itself — and flake-bot evals odin from genghis, so
    # leaving extraction on would fail that assertion and block every weekly
    # update. Off means no wifi until it's re-enabled *on odin*, with the
    # installer's firmware.cpio in place.
    extractPeripheralFirmware = false;
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
