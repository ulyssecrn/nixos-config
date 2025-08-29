# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../../dev.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "genghis";
    dhcpcd.enable = false;
    interfaces.enp6s0f1 = {
      ipv4.addresses = [{
        address = "10.10.10.12";
        prefixLength = 24;
      }];
    };
    defaultGateway = {
      address = "10.10.10.1";
      interface = "enp6s0f1";
    };
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
  };

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.supportedLocales = ["en_US.UTF-8/UTF-8" "fr_FR.UTF-8/UTF-8"];

  hardware.graphics = {
    enable = true;
  };
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
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

  services.xserver.xkb.layout = "us";

  users.users.ucorne = {
    isNormalUser = true;
    description = "Ulysse Corne";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    pkgs.mangohud
    dnsmasq
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
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  services.openssh.enable = true;

  services.ollama = {
    enable = true;
    acceleration = "cuda";
    openFirewall = true;
    host = "0.0.0.0";
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = [
      pkgs.proton-ge-bin
    ];
  };

  programs.alvr = {
    enable = true;
    openFirewall = true;
  };

  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
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
      ovmf = {
        enable = true;
        packages = [(pkgs.OVMF.override {
          secureBoot = true;
          tpmSupport = true;
        }).fd];
      };
    };
  };
  virtualisation.spiceUSBRedirection.enable = true;

  system.stateVersion = "25.05";

}
