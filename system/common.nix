{ config, lib, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  imports =
    [
      ./modules/dev.nix
      ./overlays.nix
    ];

  # ── Nix Settings ────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # ── Boot & Kernel ───────────────────────────────────────────────────
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    
    kernelParams = [ 
      "quiet"                       # Suppress most kernel log messages during boot
      "splash"                      # Show plymouth splash screen instead of text output
      "boot.shell_on_fail"          # Drop to a root shell if any boot stage fails
      "rd.systemd.show_status=auto" # Only show systemd initrd status on error/slow boot
      "rd.udev.log_level=3"         # Limit initrd udev messages to errors only
    ];

    plymouth = {
      enable = true;
      theme = "nixos-bgrt";
      themePackages = [pkgs.nixos-bgrt-plymouth];
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

  # ── Hardware ────────────────────────────────────────────────────────
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

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
    extraGroups = [ "networkmanager" "wheel" "adbusers" ];
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
  security.pam.services.greetd.enableGnomeKeyring = true;

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
    openconnect
    protonvpn-gui
    bitwarden-desktop
    gh
  ];

  programs.firefox.enable = true;
  programs.zsh.enable = true;
  programs.direnv.enable = true;
  
  security.krb5.enable = true; # Kerberos for CMU ssh login
  # ── Dynamic Libraries ───────────────────────────────────────────────
  programs.nix-ld = {
    enable = true; # unpatched dynamic libraries support
    libraries = with pkgs; [
    # General Python/Node (wiki base)
    zlib
    zstd
    stdenv.cc.cc
    curl
    openssl
    attr
    libssh
    bzip2
    libxml2
    acl
    libsodium
    util-linux
    xz
    systemd

    # Graphics / OpenGL
    libGL
    libGLU

    # X11
    libxcb
    libxext
    libx11
    libsm
    libice

    # Wayland / input
    libxkbcommon
    kdePackages.wayland

    # GUI / Qt / fonts
    glib
    fontconfig
    freetype
    dbus
    ];
  };
}

