{ config, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  imports =
    [
      ./hardware-configuration.nix
      ../../system/profiles/base.nix
      ../../system/profiles/desktop.nix
      ../../system/profiles/x86/gaming.nix
      ../../system/profiles/x86/desktop.nix
      ../../system/profiles/x86/virtualisation.nix
      ../../system/profiles/x86/containers.nix
      ./services/open-webui.nix
    ];

  # ── Boot & Kernel ───────────────────────────────────────────────────
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    kernelPackages = pkgs.linuxPackages_latest;
  };

  # ── Networking ──────────────────────────────────────────────────────
  networking = {
    hostName = "genghis";
    dhcpcd.enable = false;
    interfaces.enp6s0f1 = {
      ipv4.addresses = [{
        address = "10.10.10.9";
        prefixLength = 24;
      }];
    };
    defaultGateway = {
      address = "10.10.10.1";
      interface = "enp6s0f1";
    };
    nameservers = [
      "10.10.10.11" # hannibal pihole
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

  # ── Nix remote build server ─────────────────────────────────────────
  users.users.nix-builder = {
    isNormalUser = true;
    description = "Nix remote builder";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoDisD1xm9oUkLXmit//UlA1NrFwPjPpAeBElYQX35d loki nix-daemon -> genghis"
    ];
  };
  nix.settings.trusted-users = [ "nix-builder" ]; # merged with base.nix's ["ucorne"]

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

  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };
    openFirewall = true;
    host = "0.0.0.0";
    port = 8080;
    model = "/models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
    extraFlags = [
        "-ngl" "99"
        "-c" "8192"
        "-fa" "on"
        "--jinja"
    ];
  };

  programs.alvr = {
    enable = true;
    openFirewall = true;
  };

  # ── System ──────────────────────────────────────────────────────────
  system.stateVersion = "25.05";

}
