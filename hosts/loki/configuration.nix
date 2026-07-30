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
    # The ESP is only 256 MB and each generation's kernel+initrd is ~70 MB
    # (systemd initrd + plymouth + firmware), so ~3 sets is all that physically
    # fits.
    loader.systemd-boot.configurationLimit = 3;
    loader.efi.canTouchEfiVariables = true;

    kernelPackages = pkgs.linuxPackages_latest;

    kernelPatches = [
      # https://gitlab.freedesktop.org/drm/xe/kernel/-/work_items/7513
      # Upstream rejected this forcewake workaround in favour of dropping stolen
      # for DPT outright (Lankhorst, drm/i915/kernel@a196406a, in drm-intel-next,
      # Cc: stable). That fix lands in xe_fb_pin.c, NOT xe_ggtt.c — so when it
      # backports, this patch keeps applying and the build stays green instead of
      # conflicting. Nothing will tell you it's dead; check by hand:
      #   grep -n XE_BO_FLAG_STOLEN drivers/gpu/drm/xe/display/xe_fb_pin.c
      # Absent from the non-DGFX branch => drop this patch and the params below.
      # Verified still present (i.e. still needed) as of 7.1.5.
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

    # 15min window to decrypt luks before safe mode vs 90s default
    initrd.systemd.settings.Manager.DefaultTimeoutStartSec = "15min";

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
  # Use fingerprint for polkit prompts eg for bitwarden
  security.pam.services.polkit-1.fprintAuth = true;
  # Disable for greetd as login keyring will ask for password anyways.
  security.pam.services.greetd.fprintAuth = false;

  # Thermald is enabled by nixos-hardware/lenovo-thinkpad-x1-13th-gen
  # Potential slowness after sleep fix
  # https://bbs.archlinux.org/viewtopic.php?id=304818
  services.thermald.ignoreCpuidCheck = true;

  # Thunderbolt
  services.hardware.bolt.enable = true;

  # Copilot key → a plain second Super. Firmware sends LEFTMETA+LEFTSHIFT+F23 as
  # a *held* chord (libinput debug-events shows press/release 2.7s apart, so it
  # tracks the physical key rather than firing a one-shot burst). Super is
  # therefore already being sent — all this does is swallow the LEFTSHIFT and F23
  # riding along with it, leaving a bare Super held for as long as the key is.
  # Scoped to the internal keyboard's id so an external USB keyboard is never
  # grabbed — that also leaves you a working keyboard if this ever misbehaves.
  services.keyd = {
    enable = true;
    keyboards.internal = {
      ids = [ "0001:0001" ];
      settings = {
        # leftshift is now a chord member, so it gets buffered on every press;
        # 20ms is far more than the firmware needs (all three land in the same
        # millisecond) and keeps that buffering imperceptible.
        global.chord_timeout = 20;
        main."leftshift+f23" = "noop";
      };
    };
  };

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
    systems = [ "x86_64-linux" "i686-linux" ];
    maxJobs = 8;
    speedFactor = 4;
    supportedFeatures = [ "kvm" "nixos-test" "big-parallel" "benchmark" ];
  }];

  # ── System ─────────────────────────────────────────────────────────
  system.stateVersion = "25.11";
}

