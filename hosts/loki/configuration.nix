{ config, lib, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  imports = [
    ./hardware-configuration.nix
    ../../system/profiles/base.nix
    ../../system/profiles/desktop.nix
    ../../system/profiles/x86/gaming.nix
    ../../system/profiles/x86/desktop.nix
    ../../system/profiles/x86/virtualisation.nix
  ];

  # ── Boot & Kernel ───────────────────────────────────────────────────
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    kernelPackages = pkgs.linuxPackages_latest;

    kernelPatches = [
    # remove when upstreamed (see: https://gitlab.freedesktop.org/drm/xe/kernel/-/work_items/7513)
      {
        name = "lnl-forcewake-fix";
        patch = ./lnl-fix-v2.patch;
      }
    ];
    # remove following kernel params when fix is confirmed
    kernelParams = [ 
      "nmi_watchdog=1"              # Helps detect hard lockups
      "panic=10"                    # reboot after 10s when lockup occurs
      # https://forum.level1techs.com/t/suspend-w-linux-on-lunar-lake-2024-msi-prestige-13-ai-evo-a2vm/
      # "intel_idle.max_cstate=1  " # no effect
      # "xe.enable_psr=0"             # disable psr
      # "xe.enable_dc=0"              # disable display power states
    ];

    kernel.sysctl."kernel.sysrq" = 1;

    plymouth = {
      # Fix for pixelated splash screen on HiDPI displays
      extraConfig = ''
        DeviceScale=1
      '';
    };
  };

  # ── Networking ──────────────────────────────────────────────────────
  networking.hostName = "loki";
  # routing rules to access cmu resources directly when using cmu vpn + tailscale exit node
  networking.localCommands = ''
    ${pkgs.iproute2}/bin/ip rule add to 128.2.0.0/16 lookup main priority 90 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip rule add to 128.237.0.0/16 lookup main priority 90 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip rule add to 192.12.32.24/32 lookup main priority 90 2>/dev/null || true
  '';

  # ── Locale & Input ──────────────────────────────────────────────────
  time.timeZone = "Europe/Paris";
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

  # Thunderbolt
  services.hardware.bolt.enable = true;

  # ── Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    nvtopPackages.intel
  ];

  # ── Power Management ────────────────────────────────────────────────
  powerManagement.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
    };
  };

  # ── Distributed builds — offload to genghis ─────────────────────────
  # Key generated once with:
  #   sudo ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519_builder
  # Pubkey added to genghis's nix-builder user's authorized_keys.
  #
  # publicHostKey pins genghis's SSH host identity declaratively, so
  # nix-daemon doesn't consult /root/.ssh/known_hosts. Survives genghis
  # rebuilds (host keys aren't in the nix store). Regenerate with:
  #   ssh genghis 'base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub'
  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;
  nix.buildMachines = [{
    hostName = "genghis";
    protocol = "ssh-ng";
    sshUser = "nix-builder";
    sshKey = "/root/.ssh/id_ed25519_builder";
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUVJSUhOUTlNeUFLcXhnYjZVOHVmOG5zMysxNEI2VzdSVlBROEYxWnR3ZFUgcm9vdEBuaXhvcwo=";
    systems = [ "x86_64-linux" ];
    maxJobs = 8;
    speedFactor = 4;
    supportedFeatures = [ "kvm" "nixos-test" "big-parallel" "benchmark" ];
  }];

  # ── System ─────────────────────────────────────────────────────────
  system.stateVersion = "25.11";
}

