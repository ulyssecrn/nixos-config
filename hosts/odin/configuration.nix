{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../../dev.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.initrd.luks.devices."encrypted".device = "/dev/disk/by-uuid/bca5b73b-d63e-46dd-bd0d-6581df5e72fa";

  networking.hostName = "odin";
  #networking.wireless.enable = true;
  #MSnetworking.wireless.userControlled.enable = true;
  networking.networkmanager.enable = true;
  /*
  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };
  */

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = ["en_US.UTF-8/UTF-8" "fr_FR.UTF-8/UTF-8"];
  
  hardware.graphics = {
    enable = true;
  };

  hardware.asahi = {
    peripheralFirmwareDirectory = ./firmware;
    withRust = true;
    useExperimentalGPUDriver = true;
    setupAsahiSound = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.blueman.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.libinput.enable = true;

  services.logind.powerKey = "suspend";

  services.xserver.xkb = {
    layout = "fr";
    model = "mac";
  };

  console = {
    earlySetup = true;
    useXkbConfig = true;
  };

  users.users.ucorne = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
  ];

  programs.firefox.enable = true;

  environment.sessionVariables.MOZ_GMP_PATH = "${pkgs.widevine-firefox}/gmp-widevinecdm/system-installed";


  nixpkgs.overlays = [ 
    # 1password
    (final: prev: {
      _1password-gui = prev._1password-gui.overrideAttrs (_old: {
        postFixup = ''
          wrapProgram $out/bin/1password --set ELECTRON_OZONE_PLATFORM_HINT x11
        '';
      });
    }
    ) 
    # widevine-firefox for DRM content support
    (final: prev: {
      widevine-firefox = import ./pkgs/widevine-firefox.nix {
        stdenv = prev.stdenv;
        widevine-cdm = prev.widevine-cdm;
      };
    })
  ];

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "ucorne" ];
  };
  environment.etc = {
    "1password/custom_allowed_browsers" = {
      text = ''
        firefox
      '';
      mode = "0755";
    };
  };

  programs.zsh = {
    enable = true;
  };

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.gvfs.enable = true;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  services.openssh.enable = true;

  services.zerotierone = {
    enable = true;
    joinNetworks = [
      "db64858fed6d7cac"
    ];
  };

  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  system.stateVersion = "25.05";

}
