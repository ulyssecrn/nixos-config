{ config, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  imports =
    [
      ./hardware-configuration.nix
      ./boot.nix
      ../../system/profiles/base.nix
      ../../system/profiles/desktop.nix
      ../../system/profiles/x86/gaming.nix
      ../../system/profiles/x86/desktop.nix
      ../../system/profiles/x86/virtualisation.nix
      ../../system/profiles/x86/containers.nix
      ./services/open-webui.nix
      ./services/searxng.nix
      ./services/playwright.nix
      ./services/odysseus.nix
      ./services/librechat.nix
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
    interfaces.enp5s0.ipv4.addresses = [{
      address = "10.10.10.9";
      prefixLength = 24;
    }];
    interfaces.enp6s0f1.ipv4.addresses = [{
      address = "10.10.10.7";
      prefixLength = 24;
    }];
    defaultGateway = {
      address = "10.10.10.1";
      interface = "enp5s0";
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

  # ── CUDA binary cache ───────────────────────────────────────────────
  # Avoid recompiling llama-cpp (with cudaSupport) on every flake update.
  # cache.nixos.org doesn't ship unfree CUDA builds; this community cache
  # does. Genghis is the only host with CUDA, so this stays host-local.
  nix.settings = {
    substituters = [
      "https://cache.nixos-cuda.org"
    ];
    trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
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

  # Model + flags follow club-3090's `llamacpp/mtp-vision` recipe
  # (Q4_K_M MTP + mmproj-F16 @ 1M-px, 150K ctx, -ub 1024). The older
  # "extended-vision @ 192K + -ub 512 + 4M-px" recipe was retracted
  # 2026-05-25 (measured-false: walls at ~125K fill, OOMs at high res).
  # Single slot — agentic clients want the full KV budget per request,
  # and -np>1 silently disables MTP.
  # https://github.com/noonghunna/club-3090/blob/master/docs/SINGLE_CARD.md
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };
    openFirewall = true;
    host = "0.0.0.0";
    port = 8080;
    model = "/models/Qwen3.6-27B-Q4_K_M.gguf";
    extraFlags = [
      "-c" "150000"
      "-b" "1024"
      "-ub" "1024"
      "-ngl" "99"
      "-fa" "on"
      "--cache-type-k" "q4_0"
      "--cache-type-v" "q4_0"
      "-np" "1"
      "--mmproj" "/models/mmproj-F16.gguf"
      "--image-min-tokens" "1024"
      "--image-max-tokens" "1024"
      "--spec-type" "draft-mtp"
      "--spec-draft-n-max" "2"
      "--jinja"
      "--reasoning" "off"
      "--reasoning-format" "deepseek"
      "--temp" "0.6"
      "--top-p" "0.95"
      "--top-k" "20"
      "--min-p" "0.0"
      "--repeat-penalty" "1.0"
    ];
  };

  programs.alvr = {
    enable = true;
    openFirewall = true;
  };

  # ── System ──────────────────────────────────────────────────────────
  system.stateVersion = "25.05";

}
