# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../dev.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    plymouth = {
      enable = true;
      theme = "nixos-bgrt";
      themePackages = [pkgs.nixos-bgrt-plymouth];
      # Fix for pixelated splash screen on HiDPI displays
      extraConfig = ''
        DeviceScale=1
      '';
    };

    consoleLogLevel = 3;
    initrd.verbose = false;
    initrd.systemd.enable = true; # enable to have a gui for encryption password input
    kernelParams = [ 
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "rd.systemd.show_status=auto"
      "rd.udev.log_level=3"
      "printk.devkmsg=on"         # Prints kernel logs to the console immediately
      "log_buf_len=16M"           # Increases the size of the kernel log buffer
      "nmi_watchdog=1"            # Helps detect hard lockups
      "panic=20"
    ];
    kernel.sysctl."kernel.sysrq" = 1;
  };

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "loki"; # Define your hostname.
  networking.networkmanager = {
    enable = true;
    plugins = [ pkgs.networkmanager-openconnect ];
  };
  networking.firewall.checkReversePath = false; # for protonvpn

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  services.xserver.xkb.layout = "us";

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # Required for modern Intel GPUs (Xe iGPU and ARC)
      intel-media-driver     # VA-API (iHD) userspace
      vpl-gpu-rt             # oneVPL (QSV) runtime
      intel-compute-runtime  # OpenCL (NEO) + Level Zero for Arc/Xe
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";     # Prefer the modern iHD backend
    VDPAU_DRIVER = "va_gl";
  };

  # May help if FFmpeg/VAAPI/QSV init fails (esp. on Arc with i915):
  hardware.enableRedistributableFirmware = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.blueman.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # fingerprint scanner
  services.fprintd.enable = true;

  # fwupdmgr
  services.fwupd.enable = true;

  users.users.ucorne = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "adbusers"]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
    mangohud
    openconnect
    protonvpn-gui
    bitwarden-desktop
    nvtopPackages.intel
  ];

  programs.firefox.enable = true;

  nixpkgs.overlays = [ (
    final: prev: {
      # FreeCAD QT platform fix
      freecad = prev.freecad.overrideAttrs (_old: {
        postFixup = ''
          wrapProgram $out/bin/FreeCAD --set QT_QPA_PLATFORM xcb
        '';
      });
      # Dolphin fix for MIME apps support
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

  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "kvantum";
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  programs.zsh.enable = true;
  programs.direnv.enable = true;

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

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

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

  services.printing.enable = true;

  services.zerotierone = {
    enable = true;
    joinNetworks = [
      "db64858fed6d7cac"
    ];
  };

  services.tailscale.enable = true;
  # the two following lines are to prevent DNS issues with tailscale
  # https://github.com/tailscale/tailscale/issues/4254
  services.resolved.enable = true;
  networking.useNetworkd = false;

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

  hardware.ledger.enable = true;

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
  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}

