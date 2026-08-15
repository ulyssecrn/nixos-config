{ config, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  imports =
    [
      ./hardware-configuration.nix
      ./boot.nix
      ../../system/profiles/base.nix
      ../../system/profiles/server.nix
      ../../system/profiles/x86/gaming.nix
      ../../system/profiles/x86/virtualisation.nix
      ../../system/profiles/x86/containers.nix
      ./services/gaming.nix
      ./services/searxng.nix
      ./services/odysseus.nix
      ./services/librechat.nix
      ./services/firecrawl.nix
      ./services/restic.nix
      ./services/nix-cache.nix
      ./services/flake-bot.nix
      ./services/hermes.nix
      ./services/protonmail-bridge.nix
    ];

  # ── Boot & Kernel ───────────────────────────────────────────────────
  boot = {
    loader.systemd-boot.enable = true;
    loader.systemd-boot.configurationLimit = 10;
    loader.efi.canTouchEfiVariables = true;

    kernelPackages = pkgs.linuxPackages_latest;

    # Needed for llamacpp
    kernelModules = [ "nvidia_uvm" ];
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
    nvtopPackages.nvidia
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
  #
  # 2026-08-15: bumped Qwen3.6-27B -> Qwen3.8-27B. Same `qwen35` arch
  # (hybrid linear/full attention, 64 layers, full_attention_interval 4,
  # 4 KV heads, head_dim 256, 1 MTP layer), so every flag below carries
  # over unchanged — only the two file paths move. Q4_K_M over the newer
  # UD-Q4_K_XL deliberately: XL is +0.8G and this card sits at ~22.3/24G
  # already, so XL would leave <1G and OOM near a full 150K fill.
  # mmproj is Qwen3.8's own — the 3.6 one at /models/mmproj-F16.gguf is
  # kept for rollback and is NOT interchangeable.
  # Note: club-3090 restructured SINGLE_CARD.md on 2026-08-12 and retired
  # the llamacpp path (single-card is vLLM-only there now, 32K ceiling).
  # This recipe is therefore unmaintained upstream but still correct here
  # — the llama.cpp path was retired as unmaintained, not as broken.
  # Sampling below is Qwen3.6's "thinking, precise coding" preset
  # (temp 0.6 / top-p 0.95); Qwen3.8's card drops that preset and lists
  # only thinking (1.0/0.95) and instruct (0.7/0.80 + presence 1.5).
  # Kept as-is on purpose; revisit if output quality shifts.
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };
    openFirewall = true;
    settings = {
      host = "0.0.0.0";
      port = 8080;
      model = "/models/Qwen3.8-27B-Q4_K_M.gguf";
      ctx-size = 150000;
      batch-size = 1024;
      ubatch-size = 1024;
      n-gpu-layers = 99;
      flash-attn = "on";
      cache-type-k = "q4_0";
      cache-type-v = "q4_0";
      parallel = 1;
      mmproj = "/models/Qwen3.8-mmproj-F16.gguf";
      image-min-tokens = 1024;
      image-max-tokens = 1024;
      spec-type = "draft-mtp";
      spec-draft-n-max = 2;
      jinja = true;
      reasoning = "off";
      reasoning-format = "deepseek";
      temp = 0.6;
      top-p = 0.95;
      top-k = 20;
      min-p = 0.0;
      repeat-penalty = 1.0;
    };
  };

  programs.alvr = {
    enable = true;
    openFirewall = true;
  };

  # ── Tailscale ───────────────────────────────────────────────────────
  services.tailscale = {
    useRoutingFeatures = "server";
    openFirewall = true;
    extraSetFlags = [
      "--advertise-routes=10.10.10.0/24"
    ];
  };

  # ── System ──────────────────────────────────────────────────────────
  system.stateVersion = "25.05";

}
