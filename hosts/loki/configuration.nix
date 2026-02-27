{ config, lib, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  imports = [
    ./hardware-configuration.nix
    ../../common.nix
    ../../common_x86.nix
  ];

  # ── Boot & Kernel ───────────────────────────────────────────────────
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams = [ 
      "nmi_watchdog=1"              # Helps detect hard lockups
      "panic=10"                    # reboot after 10s when lockup occurs
      # https://forum.level1techs.com/t/suspend-w-linux-on-lunar-lake-2024-msi-prestige-13-ai-evo-a2vm/
      # "intel_idle.max_cstate=1  " # no effect
      "xe.enable_psr=0"             # disable psr
      "xe.enable_dc=0"              # disable display power states
    ];

    kernel.sysctl."kernel.sysrq" = 1;

    plymouth = {
      # Fix for pixelated splash screen on HiDPI displays
      extraConfig = ''
        DeviceScale=1
      '';
    };
  };

  # Hardware error logging
  hardware.rasdaemon = {
    enable = true;
    record = true;
  };

  # ── Networking ──────────────────────────────────────────────────────
  networking.hostName = "loki";

  # ── Locale & Input ──────────────────────────────────────────────────
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  services.xserver.xkb.layout = "us";

  # ── Hardware ────────────────────────────────────────────────────────
  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver     # VA-API (iHD) userspace
      vpl-gpu-rt             # oneVPL (QSV) runtime
      intel-compute-runtime  # OpenCL (NEO) + Level Zero for Arc/Xe
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER = "va_gl";
  };

  # Trackpad
  services.libinput.enable = true;

  # Fingerprint scanner
  services.fprintd.enable = true;

  # ── Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    nvtopPackages.intel
  ];

  # ── Power Management ────────────────────────────────────────────────
  powerManagement.enable = true;
  powerManagement.powertop.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
    };
  };

  # ── System ─────────────────────────────────────────────────────────
  system.stateVersion = "25.11";
}

