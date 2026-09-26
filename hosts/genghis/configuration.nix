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

    # Both NICs sit on 10.10.10.0/24, so each contributes an identical
    # connected route. The kernel does NOT skip a route over a carrier-less
    # link by default - it only flags it RTNH_F_LINKDOWN - so the winner was
    # whichever network-addresses-* unit installed its route last. On
    # 2026-09-01 a `nixos-rebuild switch` restarted both units in parallel and
    # enp6s0f1 (Realtek, no cable) got its address back first: the whole /24
    # started resolving out a dead port and the box fell off the LAN 15 min
    # later, once the cached neighbour entries expired and ARP had to be
    # redone ("No route to host" to 10.10.10.11). Ordering-dependent, hence
    # intermittent. This makes the choice depend on carrier rather than unit
    # start order, and doubles as failover if the cable ever moves ports.
    kernel.sysctl = {
      "net.ipv4.conf.all.ignore_routes_with_linkdown" = 1;
      "net.ipv4.conf.default.ignore_routes_with_linkdown" = 1;
    };
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
    # Intel (enp5s0) is the intended path. ignore_routes_with_linkdown (see
    # boot.kernel.sysctl above) only fixes the *connected* /24 route; the
    # default route is pinned `dev enp5s0`, so once enp5s0 loses carrier that
    # route is excluded too and nothing replaces it - on-subnet traffic would
    # fail over but the box would be left with no gateway at all. The higher
    # metric keeps this route inert while enp5s0 still has carrier.
    interfaces.enp6s0f1.ipv4.routes = [{
      address = "0.0.0.0";
      prefixLength = 0;
      via = "10.10.10.1";
      options.metric = "600";
    }];

    defaultGateway = {
      address = "10.10.10.1";
      interface = "enp5s0";
      metric = 100;
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

  # Model + flags: club-3090's `qwen38-27b-single-iq4xs` slug, which this now
  # tracks closely: UD-IQ4_XS + q4_0 KV + 262K + vision. We differ in keeping
  # the projector in system RAM (club-3090 #1380).
  # https://github.com/noonghunna/club-3090/blob/master/docs/SINGLE_CARD.md
  #
  # WHY UD-IQ4_XS over Q4_K_M: 13.27 GiB vs 15.93 GiB. That 2.66 GiB is what
  # pays for everything below. It costs 0.84 bpw (4.17 vs 5.01) — a real if
  # unmeasured quality loss; nobody has benched this pair.
  #
  # WHY q4_0 KV (2026-09-26, was q8_0 @ 200,704): q8_0 cannot reach the full
  # 262,144 on one card, and Qwen evaluates agentic coding (Claude Code
  # harness) at 256K. The trade is unmeasured on this model: q4_0 KLD is ~5.75x
  # q8_0's in general, but only the 16 full-attention layers hold KV — the 48
  # DeltaNet layers keep their recurrent state unquantized — so it touches a
  # quarter of the network. club-3090 addressed 240,635 tok cleanly at q4_0
  # (uniform haystack, NOT retrieval quality). If long-session quality drops,
  # fall back to q8_0 @ 200,704 (measured below). q8_0 K + q4_0 V would fit
  # 262K in the same 6.5 GiB, but mixed K/V types under flash-attn need a
  # GGML_CUDA_FA_ALL_QUANTS build, which the CUDA cache doesn't carry.
  #
  # WHY THE PROJECTOR IN RAM (no-mmproj-offload): ~0 VRAM instead of
  # ~1,180 MiB; an image then costs ~1.5 s of CPU encode instead of 0.6 s on
  # the GPU (club-3090 #1380). Text decode is unaffected.
  #
  # KV math (hybrid arch: 64 layers, full_attention_interval 4 => only 16
  # KV-growing layers, so do NOT reason about this with dense-attention math):
  #   per_token = 16 * 4 heads * 256 head_dim * 2 * bpe = 32,768 * bpe
  #   q4_0 -> 18,432 B/tok -> 262,144 ctx = 4.50 GiB
  #   q8_0 -> 34,816 B/tok -> 200,704 ctx = 6.51 GiB
  #
  # MEASURED on this card 2026-08-27, q8_0 @ 200,704 (scripts/try-ctx.sh):
  #   boot 23,156 MiB / 24,576 (1.39 GiB free); 187,934-token prefill peaked
  #   at 23,192 MiB — only +36 MiB, because -ub 1024 caps the per-pass
  #   activation buffer — and recalled a needle at 90% depth. Decode ~86 tok/s
  #   (was ~66 on Q4_K_M; decode is bandwidth-bound, so lighter weights win).
  #   212,992 also boots but leaves 0.85 GiB — rejected, +6% ctx for half the
  #   margin. 229,376 does not fit.
  #   ⚠️ That fill test is ADDRESSABILITY on a uniform haystack, not retrieval
  #   quality — the same caveat club-3090 puts on their own NIAH numbers.
  # q4_0 @ 262,144 is NOT yet measured here: `try-ctx.sh 262144 1024 q4_0`.
  #
  # Single slot — agentic clients want the full KV budget per request, and
  # -np>1 silently disables MTP.
  #
  # Thinking ON by default, at the template's default effort, xhigh. Qwen's
  # card: in multi-turn agentic work lower effort "does not always reduce
  # overall task completion time" (more failures and retries). Supported
  # efforts are xhigh, medium and low; the embedded template silently maps
  # `high` to xhigh and raises on anything else. Clients pick per request via
  # chat_template_kwargs (enable_thinking, reasoning_effort). xhigh needs a
  # big output budget: the answer comes after </think>, so a small max_tokens
  # returns EMPTY content (finish_reason=length). Sampling is the card's
  # thinking row (1.0 / 0.95 / 20 / 0, presence 0).
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };
    openFirewall = true;
    settings = {
      host = "0.0.0.0";
      port = 8080;
      model = "/models/Qwen3.8-27B-UD-IQ4_XS.gguf";
      mmproj = "/models/Qwen3.8-mmproj-F16.gguf";
      no-mmproj-offload = true;
      ctx-size = 262144;
      batch-size = 4096;
      ubatch-size = 1024;
      n-gpu-layers = 99;
      flash-attn = "on";
      cache-type-k = "q4_0";
      cache-type-v = "q4_0";
      parallel = 1;
      spec-type = "draft-mtp";
      spec-draft-n-max = 2;
      jinja = true;
      reasoning = "on";
      reasoning-format = "deepseek";
      temp = 1.0;
      top-p = 0.95;
      top-k = 20;
      min-p = 0.0;
      repeat-penalty = 1.0;
    };
  };
  # Pinned rather than left to the template's own default (also xhigh), so a
  # template change can't silently move it. Via env, not `settings`: the
  # module joins settings into ExecStart unquoted, and systemd would strip
  # the JSON's quotes.
  systemd.services.llama-cpp.environment.LLAMA_ARG_CHAT_TEMPLATE_KWARGS =
    builtins.toJSON { reasoning_effort = "xhigh"; };

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
