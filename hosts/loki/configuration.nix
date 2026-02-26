{ config, lib, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  imports = [
    ./hardware-configuration.nix
    ../../dev.nix
  ];

  # ── Nix Settings ────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # ── Boot & Kernel ───────────────────────────────────────────────────
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    
    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams = [ 
      "quiet"                       # Suppress most kernel log messages during boot
      "splash"                      # Show plymouth splash screen instead of text output
      "boot.shell_on_fail"          # Drop to a root shell if any boot stage fails
      "rd.systemd.show_status=auto" # Only show systemd initrd status on error/slow boot
      "rd.udev.log_level=3"         # Limit initrd udev messages to errors only
      "nmi_watchdog=1"              # Helps detect hard lockups
      "panic=10"                    # reboot after 10s when lockup occurs
      # https://forum.level1techs.com/t/suspend-w-linux-on-lunar-lake-2024-msi-prestige-13-ai-evo-a2vm/
      # "intel_idle.max_cstate=1  " # no effect
      "xe.enable_psr=0"             # disable psr
      "xe.enable_dc=0"              # disable display power states
    ];

    kernel.sysctl."kernel.sysrq" = 1;

    plymouth = {
      enable = true;
      theme = "nixos-bgrt";
      themePackages = [pkgs.nixos-bgrt-plymouth];
      # Fix for pixelated splash screen on HiDPI displays
      extraConfig = ''
        DeviceScale=1
      '';
    };

    initrd.verbose = false;
    initrd.systemd.enable = true; # Enables GUI for encryption password input

    consoleLogLevel = 3;
  };

  # Hardware error logging
  hardware.rasdaemon = {
    enable = true;
    record = true;
  };

  # ── Networking ──────────────────────────────────────────────────────
  networking.hostName = "loki";

  networking.networkmanager = {
    enable = true;
    plugins = [ pkgs.networkmanager-openconnect ];
  };

  networking.firewall.checkReversePath = "loose"; # ProtonVPN

  services.zerotierone = {
    enable = true;
    joinNetworks = [ "db64858fed6d7cac" ];
  };

  services.tailscale.enable = true;
  # the two following lines are to prevent DNS issues with tailscale
  # https://github.com/tailscale/tailscale/issues/4254
  services.resolved.enable = true;
  networking.useNetworkd = false;

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


  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Trackpad
  services.libinput.enable = true;

  # Fingerprint scanner
  services.fprintd.enable = true;

  # Ledger wallet
  hardware.ledger.enable = true;

  services.printing.enable = true;
  
  # fwupdmgr
  services.fwupd.enable = true;

  # ── Audio ───────────────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # ── Users ───────────────────────────────────────────────────────────
  users.users.ucorne = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "adbusers" "libvirtd" "kvm" ];
    shell = pkgs.zsh;
  };

  # ── Desktop Environment ─────────────────────────────────────────────
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };  
  
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.gvfs.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start default'";
        user = "greeter";
      };
    };
  };

  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "kvantum";
  };

  # ── Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    mangohud
    openconnect
    protonvpn-gui
    bitwarden-desktop
    nvtopPackages.intel
  ];

  programs.firefox.enable = true;
  programs.zsh.enable = true;
  programs.direnv.enable = true;

  # ── Gaming ──────────────────────────────────────────────────────────
  # gamescope is broken for now in steam
  # https://discourse.nixos.org/t/gamescope-refuses-to-work-with-steam/71417/23
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
  programs.steam = {
    enable = true;
    extest.enable = true; # controller mouse support on wayland
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = [
      pkgs.proton-ge-bin
    ];
    gamescopeSession.enable = true;
  };
  
  # ── Overlays ────────────────────────────────────────────────────────
  nixpkgs.overlays = [ (
    final: prev: {
      # Dolphin fix for MIME apps support
      # https://discourse.nixos.org/t/dolphin-does-not-have-mime-associations/
      kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
          dolphin = kprev.dolphin.overrideAttrs (oldAttrs: {
            nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
            postInstall = (oldAttrs.postInstall or "") + ''
              wrapProgram $out/bin/dolphin \
                  --set XDG_CONFIG_DIRS "${prev.libsForQt5.kservice}/etc/xdg:$XDG_CONFIG_DIRS" \
                  --run "${kprev.kservice}/bin/kbuildsycoca6 --noincremental ${prev.libsForQt5.kservice}/etc/xdg/menus/applications.menu"
            '';
          });
        });
    }
    ) 
  ];


  # ── Dynamic Libraries ───────────────────────────────────────────────
  programs.nix-ld = {
    enable = true; # unpatched dynamic libraries support
    libraries = with pkgs; [
      # the following libraries are needed for matplotlib windows (pyqt5)
      # to work with a uv-managed python install
      libGL # libGL.so
      glib # libglib-2.0.so.0, libgthread-2.0.so.0
      libxkbcommon
      kdePackages.wayland
      fontconfig
      freetype
      dbus
    ];
  };

  # ── Virtualisation ──────────────────────────────────────────────────
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["ucorne"];
  users.groups.kvm.members = [ "ucorne" ];

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };
  virtualisation.spiceUSBRedirection.enable = true;

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

