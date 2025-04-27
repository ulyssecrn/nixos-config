{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.initrd.luks.devices."encrypted".device = "/dev/disk/by-uuid/bca5b73b-d63e-46dd-bd0d-6581df5e72fa";

  networking.hostName = "odin";
  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

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

  nixpkgs.overlays = [ (
    final: prev: {
      _1password-gui = prev._1password-gui.overrideAttrs (_old: {
        postFixup = ''
          wrapProgram $out/bin/1password --set ELECTRON_OZONE_PLATFORM_HINT x11
        '';
      });
    }
    ) 
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
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
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

  system.stateVersion = "25.05";

}
