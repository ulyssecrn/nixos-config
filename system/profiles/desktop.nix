{ config, lib, pkgs, ... }:

{
  # ── Boot & Kernel ───────────────────────────────────────────────────
  boot = {
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
      themePackages = [ pkgs.nixos-bgrt-plymouth ];
    };

    initrd.verbose = false;
    initrd.systemd.enable = true; # Enables GUI for encryption password input

    consoleLogLevel = 3;
  };

  # ── Networking ──────────────────────────────────────────────────────
  networking.networkmanager = {
    enable = true;
    plugins = [ pkgs.networkmanager-openconnect ];
  };

  networking.firewall.checkReversePath = "loose"; # ProtonVPN

  # ── Hardware ────────────────────────────────────────────────────────
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      Experimental = true;
    };
  };

  services.blueman.enable = true;

  services.printing.enable = true;
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;

  # bitwarden-desktop in current nixpkgs unstable still bundles
  # electron-39.8.10 which is EOL. The bump is tracked in nixpkgs#521305
  # but hasn't landed in our unstable snapshot yet. Drop once it does.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

  # ── Audio ───────────────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    wireplumber.extraConfig."10-bluez" = {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        "bluez5.roles" = [ "a2dp_sink" "a2dp_source" ];
      };
    };
  };

  # ── Users ───────────────────────────────────────────────────────────
  users.users.ucorne.extraGroups = [ "networkmanager" "adbusers" "dialout" ];

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
  # hyprlock comes from home-manager (home/modules/hyprlock.nix), which can't
  # write /etc/pam.d — without this hyprlock authenticates against the `su` stack
  # and every unlock fails ("Authentication failed for su"), leaking a live
  # hyprlock that then makes hypridle's `pidof hyprlock` guard suppress all
  # later locks. fprintAuth defaults to services.fprintd.enable, but hyprlock
  # drives the reader itself (auth.fingerprint) — leave PAM on password only so
  # the two don't both claim the device.
  security.pam.services.hyprlock.fprintAuth = false;
  # A screen lock only ever needs to check the local Unix password, and the CMU
  # krb5 stack below is actively harmful here: pam_ccreds' helper binary isn't
  # installed, and hyprlock segfaults in CPam::auth() walking past it — which
  # leaves a live hyprlock behind, and that in turn makes hypridle's
  # `pidof hyprlock` guard suppress every subsequent lock. krb5.enable is global,
  # so switch the rules off for this one service.
  # mkForce: the pam module defines these as `config.security.pam.krb5.enable`
  # at normal priority, so a plain `false` collides instead of overriding.
  security.pam.services.hyprlock.rules.auth = {
    krb5.enable = lib.mkForce false;
    ccreds-validate.enable = lib.mkForce false;
    ccreds-store.enable = lib.mkForce false;
  };

  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "kvantum";
  };

  # ── Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    openconnect
    proton-vpn
    bitwarden-desktop
  ];

  programs.firefox.enable = true;
  programs.localsend.enable = true;

  # ── CMU Authentication ──────────────────────────────────────────────
  security.krb5 = {
    enable = true;
    settings = {
      libdefaults = {
        default_realm = "ANDREW.CMU.EDU";
        forwardable = true;
        proxiable = true;
        noaddresses = true;
      };
    };
  };

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
