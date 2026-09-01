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

  # Model + flags: club-3090's `qwen38-27b-single-iq4xs` slug, re-tuned here
  # for a text-only serving profile. Theirs is a "max everything" exhibit —
  # UD-IQ4_XS + q4_0 KV + 262K + vision projector. We keep the quant, drop the
  # projector, and spend the freed VRAM on q8_0 KV instead of more context.
  # https://github.com/noonghunna/club-3090/blob/master/docs/SINGLE_CARD.md
  #
  # WHY UD-IQ4_XS over Q4_K_M: 13.27 GiB vs 15.93 GiB. That 2.66 GiB is what
  # pays for everything below. It costs 0.84 bpw (4.17 vs 5.01) — a real if
  # unmeasured quality loss; nobody has benched this pair and club-3090 has
  # not run an 8-pack on the slug (it is 🐣 incubating for that reason).
  #
  # WHY q8_0 KV: club-3090's floor policy is q8_0-grade for anything that
  # serves; q4_0 sits below it and has never been depth-validated on this
  # DeltaNet hybrid family. We ran q4_0 for months because it was the only way
  # to reach 150K on Q4_K_M. With the lighter weights it no longer is.
  #
  # WHY NO VISION: nothing here consumes it — opencode, hermes and the Copilot
  # BYOK endpoint are all text. LibreChat loses image upload. The projector
  # cost 0.86 GiB, which is ~26K tokens of q8_0 KV.
  #
  # KV math (hybrid arch: 64 layers, full_attention_interval 4 => only 16
  # KV-growing layers, so do NOT reason about this with dense-attention math):
  #   per_token = 16 * 4 heads * 256 head_dim * 2 * bpe = 32,768 * bpe
  #   q8_0 -> 34,816 B/tok -> 200,704 ctx = 6.51 GiB
  #   q4_0 -> 18,432 B/tok (what we left behind)
  #
  # MEASURED on this card 2026-08-27 (hosts/genghis/scripts/try-ctx.sh):
  #   boot 23,156 MiB / 24,576 (1.39 GiB free); 187,934-token prefill peaked
  #   at 23,192 MiB — only +36 MiB, because -ub 1024 caps the per-pass
  #   activation buffer — and recalled a needle at 90% depth. Decode ~86 tok/s
  #   (was ~66 on Q4_K_M; decode is bandwidth-bound, so lighter weights win).
  #   212,992 also boots but leaves 0.85 GiB — rejected, +6% ctx for half the
  #   margin. 229,376 does not fit.
  #   ⚠️ That fill test is ADDRESSABILITY on a uniform haystack, not retrieval
  #   quality — the same caveat club-3090 puts on their own NIAH numbers.
  #
  # Single slot — agentic clients want the full KV budget per request, and
  # -np>1 silently disables MTP. Sampling stays on Qwen3.6's "thinking,
  # precise coding" preset (temp 0.6 / top-p 0.95); Qwen3.8's card drops that
  # preset and lists only thinking (1.0/0.95) and instruct (0.7/0.80 +
  # presence 1.5). Kept on purpose; revisit if output quality shifts.
  #
  # `reasoning = "off"` is only a DEFAULT — clients can opt in per request with
  # chat_template_kwargs {enable_thinking, reasoning_effort}. Always send
  # reasoning_effort explicitly: the template defaults to `xhigh`, which
  # overruns token budgets and returns EMPTY content (finish_reason=length)
  # because the answer is emitted after </think>. `low` is the usable level;
  # `minimal`/`max` raise a Jinja exception on this template despite
  # llama.cpp's --reasoning-effort help text advertising them.
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };
    openFirewall = true;
    settings = {
      host = "0.0.0.0";
      port = 8080;
      model = "/models/Qwen3.8-27B-UD-IQ4_XS.gguf";
      ctx-size = 200704;
      batch-size = 4096;
      ubatch-size = 1024;
      n-gpu-layers = 99;
      flash-attn = "on";
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      parallel = 1;
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

  # ── Metrics ─────────────────────────────────────────────────────────
  # node exporter + the tailscale0-only firewall rule come from
  # system/modules/metrics.nix; these are the genghis-specific ones. Scraped
  # by atilla (hosts/atilla/services/monitoring.nix).
  services.prometheus.exporters = {
    smartctl.enable = true;   # autodiscovers; module ACLs /dev/nvme* via udev
    "nvidia-gpu".enable = true;  # 3090 — VRAM/util/temp while llama.cpp is loaded

    # rasdaemon already runs fleet-wide (base.nix, record = true); this turns
    # its event DB into metrics, so a repeat of the 2026-06-16 uncorrected
    # machine-check is a counter with a timestamp rather than a journal line.
    rasdaemon.enable = true;
  };

  # ── System ──────────────────────────────────────────────────────────
  system.stateVersion = "25.05";

}
