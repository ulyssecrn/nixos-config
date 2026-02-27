{ config, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  imports =
    [
      ./hardware-configuration.nix
      ../../system/common.nix
      ../../system/common_x86.nix
    ];

  # ── Networking ──────────────────────────────────────────────────────
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
      address = "10.10.10.11";
      interface = "enp6s0f1";
    };
    nameservers = [
      "10.10.10.5"
    ];
  };

  # ── Locale & Input ──────────────────────────────────────────────────
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = ["en_US.UTF-8/UTF-8" "fr_FR.UTF-8/UTF-8"];
  services.xserver.xkb.layout = "us";

  # ── Hardware ────────────────────────────────────────────────────────
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

  # ── Users ───────────────────────────────────────────────────────────
  users.users.ucorne = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAsvz9y+oOCCyAFlwfbfXjJ1+NCEsv4Y5G/3ZJ4a75nr" # Odin - Bitwarden
    ];
  };

  # ── Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    dnsmasq
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  services.ollama = {
    enable = true;
    acceleration = "cuda";
    openFirewall = true;
    host = "0.0.0.0";
  };

  programs.alvr = {
    enable = true;
    openFirewall = true;
  };

  # ── System ──────────────────────────────────────────────────────────
  system.stateVersion = "25.05";

}
