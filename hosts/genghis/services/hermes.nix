{ config, lib, pkgs, ... }:

let
  # Tokyo Night (dark) TUI skin, matching the fleet Stylix palette in
  # home/modules/stylix.nix. Hermes exposes no NixOS option for skins, so we
  # render the YAML to the store and symlink it into ~/.hermes/skins/ via
  # tmpfiles (below); `settings.display.skin` then selects it. Skin schema:
  # https://hermes-agent.nousresearch.com/docs/user-guide/features/skins
  tokyoNightSkin = pkgs.writeText "tokyo-night.yaml" ''
    name: tokyo-night
    description: Tokyo Night dark — matches the fleet Stylix palette

    # banner_logo / banner_hero intentionally left unset → inherit the built-in
    # HERMES-AGENT logo + caduceus (now drawn in the Tokyo Night palette).
    # Blanking them collapses the hero column and mangles the session panel.
    colors:
      banner_border: "#414868"    # base03
      banner_title: "#c0caf5"     # base05 fg
      banner_accent: "#7aa2f7"    # base0D blue
      banner_dim: "#545c7e"       # base04
      banner_text: "#c0caf5"      # base05 fg
      ui_accent: "#7aa2f7"        # base0D
      ui_label: "#bb9af7"         # base0E magenta
      ui_ok: "#9ece6a"            # base0B green
      ui_error: "#f7768e"         # base08 red
      ui_warn: "#e0af68"          # base0A yellow
      prompt: "#c0caf5"           # base05
      input_rule: "#414868"       # base03
      response_border: "#7aa2f7"  # base0D
      session_label: "#7aa2f7"    # base0D
      session_border: "#414868"   # base03
      status_bar_bg: "#16161e"    # base01 panel
      status_bar_text: "#c0caf5"  # base05
      status_bar_strong: "#7aa2f7"   # base0D
      status_bar_dim: "#545c7e"      # base04
      status_bar_good: "#9ece6a"     # base0B green
      status_bar_warn: "#e0af68"     # base0A yellow
      status_bar_bad: "#ff9e64"      # base09 orange
      status_bar_critical: "#db4b4b" # base0F deep red (distinct from error)
      voice_status_bg: "#16161e"                 # base01
      selection_bg: "#283457"                    # base02
      completion_menu_bg: "#16161e"              # base01
      completion_menu_current_bg: "#283457"      # base02
      completion_menu_meta_bg: "#16161e"         # base01
      completion_menu_meta_current_bg: "#283457" # base02

    # No `spinner:` block: a skin's spinner faces/verbs/wings are read ONLY by
    # the classic CLI — the Ink TUI ignores them (the gateway's resolve_skin
    # forwards colors/branding/banner/tool_prefix, not spinner). The TUI's
    # bottom-left animated face is the "pet" (toggle/change via `/pet`, backed
    # by display.pet.*), and its tiny loader is a hardcoded braille spinner —
    # neither is skinnable. branding also omitted → inherits Hermes defaults.
    tool_prefix: "│"
  '';
in
{
  # Hermes — Nous Research's agentic assistant.
  # https://hermes-agent.nousresearch.com/docs
  #
  # WHY container mode (not the native systemd service):
  # Hermes is an *agent* — it runs shell commands, does browser automation
  # and installs its own tools at runtime. The module's `container.enable`
  # runs the whole thing inside a mutable Ubuntu OCI container (Nix-built
  # binary bind-mounted read-only from /nix/store), so:
  #   - a rogue tool call is boxed in the container, not on the NixOS host
  #   - the agent can pip/npm/apt-install freely inside that box (the native
  #     mode is immutable and those would fail)
  #   - config still lives here, declaratively.
  # Backend is podman to match the rest of genghis (system/profiles/x86/
  # containers.nix); native mode would also pull in docker, which we avoid.
  #
  # WHY no GPU flag: Hermes does no inference itself — it points at the
  # existing llama.cpp OpenAI endpoint on the host (:8080/v1). The 3090 Ti
  # stays entirely with llama.cpp. (Add `--gpus all` under container.
  # extraOptions only if you later want Hermes doing its own GPU work,
  # e.g. local whisper STT.)
  #
  # Secrets (the placeholder API key llama.cpp requires) live outside the
  # nix store at /var/lib/hermes/env. Create once:
  #   sudo install -d -m 0700 /var/lib/hermes
  #   echo 'OPENAI_API_KEY=sk-local-unused' | sudo tee /var/lib/hermes/env
  #   sudo chmod 0600 /var/lib/hermes/env
  #
  # NB: Nix/NixOS is a Tier-2 ("best-effort") target for Hermes and this
  # module is young — after adding the flake input, sanity-check the exact
  # option names it exposes with:
  #   nix eval .#nixosConfigurations.genghis.options.services.hermes-agent \
  #     --apply builtins.attrNames
  # and adjust below if any differ from the docs.

  services.hermes-agent = {
    enable = true;

    # Put a `hermes` wrapper on the host PATH that transparently execs into
    # the managed container (all flags forwarded). Without this the binary
    # only exists inside the container under /data and isn't callable from
    # the host — so `hermes --tui` on genghis "just works" with this on.
    addToSystemPackages = true;

    # ── Isolation ────────────────────────────────────────────────────
    container = {
      enable = true;
      backend = "podman";
      image = "ubuntu:24.04";
      # Symlinks host ~/.hermes ↔ container state so the host CLI shares
      # sessions/config/memories with the containerised agent.
      hostUsers = [ "ucorne" ];
      # Give the agent a host workspace it can read/write project files in.
      # extraVolumes = [ "/srv/hermes/projects:/projects:rw" ];
    };

    # ── Model: the local llama.cpp on this same host ─────────────────
    # We target the host's stable LAN IP rather than host.containers.internal
    # so it doesn't depend on the module wiring a host-gateway alias — the
    # podman bridge NATs out to 10.10.10.9 and llama-cpp's openFirewall opens
    # :8080. llama.cpp ignores the `model` field (single loaded model), so its
    # value is cosmetic; the api_key is only there because OpenAI clients
    # insist on a non-empty one (comes from environmentFiles).
    settings = {
      model = {
        # `custom` = a self-hosted OpenAI-compatible server reached via
        # base_url. `openai` would mean the real OpenAI API (hence the
        # "unknown provider" only shows once it tries to init that client).
        provider = "custom";
        default  = "qwen3.6";                     # cosmetic (llama.cpp ignores it) — but it's also the model label in the TUI tab title (marker · session · model · cwd) and startup banner, so kept short
        base_url = "http://10.10.10.9:8080/v1";
        api_key  = "none";                        # llama.cpp ignores it; placeholder keeps the client happy
      };

      # Shell commands run *inside* this (already isolated) container — the
      # whole point of container mode. Don't set this to "docker"/"ssh".
      terminal = {
        backend = "local";
        timeout = 180;
      };

      # Sensible defaults; tune once it's running.
      agent.max_turns = 60;
      memory.memory_enabled = true;

      # Web search/extract — both fully self-hosted on this same host.
      # search_backend → SearXNG (metasearch, :8888); extract_backend →
      # Firecrawl (:3002), which scrapes/crawls the pages SearXNG finds.
      # Splitting the two keeps search alive if Firecrawl is down and avoids
      # a proxy hop — self-hosted Firecrawl's own search would just call
      # SearXNG anyway. Endpoints/keys are non-secret → in `environment`.
      web = {
        search_backend = "searxng";
        extract_backend = "firecrawl";
      };

      display.interface = "tui";  # "cli" (default) or "tui"

      display.tui_compact = true;

      # TUI appearance. Custom `tokyo-night` skin (rendered in the `let` above,
      # symlinked into ~/.hermes/skins via tmpfiles below) — recolors the whole
      # TUI to the fleet Stylix palette. Switch live with `/skin`.
      display.skin = "tokyo-night";

      display.pet.enabled = false;
    };

    # ── Web dashboard (behind atilla's caddy, like the other services) ──
    # These land in the container's .env (the module seeds `environment` +
    # `environmentFiles` there) and are read by the dashboard launched in the
    # `hermes-dashboard` unit below. A non-loopback bind is mandatory-auth
    # since the June-2026 hardening (`--insecure` is a no-op), so the built-in
    # `basic` provider is on: username here (non-secret), password in the env
    # file. public_url gives the login/callback logic the real proxied origin.
    # NB `HERMES_DASHBOARD=1` auto-supervision is s6-image-only — no effect in
    # this ubuntu+nix container — hence we start the dashboard explicitly.
    environment = {
      HERMES_DASHBOARD_BASIC_AUTH_USERNAME = "ucorne";
      HERMES_DASHBOARD_PUBLIC_URL = "http://hermes.corne.sh";

      # Self-hosted web backends on this same host. The container runs
      # --network=host, so its loopback IS the host loopback — use 127.0.0.1
      # for both. This is required for Firecrawl: it publishes only to
      # 127.0.0.1:3002 (loopback), so the host LAN IP won't reach it. SearXNG
      # binds 0.0.0.0 but loopback hits it too; kept on 127.0.0.1 to match.
      # SearXNG already emits JSON (enabled for LibreChat). Firecrawl runs
      # USE_DB_AUTHENTICATION=false, so the key is a non-empty placeholder.
      SEARXNG_URL = "http://127.0.0.1:8888";
      FIRECRAWL_API_URL = "http://127.0.0.1:3002";
      FIRECRAWL_API_KEY = "self-hosted-no-key-needed";
    };

    # ── Secrets & state ──────────────────────────────────────────────
    environmentFiles = [ "/var/lib/hermes/env" ];
    stateDir = "/var/lib/hermes";
    restart = "always";
  };

  # The dashboard listens on :9119 (host netns via --network=host). Open it on
  # the LAN so atilla's caddy can reverse-proxy hermes.corne.sh → 10.10.10.9:9119,
  # same as the other genghis services. Access is still gated by the dashboard's
  # own basic-auth login (LAN/Tailscale are trusted transports; the password is
  # the second factor for the one service that can drive an agent shell).
  networking.firewall.allowedTCPPorts = [ 9119 ];

  # Hermes has no module option for skins, and `environment.etc` only targets
  # /etc — so for this /var state path, systemd-tmpfiles is the idiomatic NixOS
  # mechanism (the same store-symlink `environment.etc` does, and what this
  # module uses for its own dirs). Create the skins dir and force-symlink the
  # store-rendered YAML into it. The container sees it at /data/.hermes/skins
  # (stateDir mount); the target resolves through the read-only /nix/store mount.
  systemd.tmpfiles.settings.hermes-skins = {
    "/var/lib/hermes/.hermes/skins".d = {
      user = "hermes";
      group = "hermes";
      mode = "2770";
    };
    "/var/lib/hermes/.hermes/skins/tokyo-night.yaml"."L+".argument = "${tokyoNightSkin}";
  };

  # The module's container is ubuntu+nix (no s6 supervisor), so the dashboard
  # isn't auto-started. Launch it by exec-ing the same binary the host `hermes`
  # wrapper uses (as the container's `hermes` user, per the module's
  # .container-mode metadata), bound to the LAN so caddy can reach it. Tied to
  # the gateway container's lifecycle via partOf/requires.
  systemd.services.hermes-dashboard = {
    description = "Hermes web dashboard (LAN-bound, behind atilla caddy)";
    after = [ "hermes-agent.service" ];
    requires = [ "hermes-agent.service" ];
    partOf = [ "hermes-agent.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 10;
      ExecStart = "${pkgs.podman}/bin/podman exec -u hermes hermes-agent /data/current-package/bin/hermes dashboard --host 0.0.0.0 --port 9119 --no-open";
    };
  };

  # The gateway container is rootful (its systemd unit runs as root), so a
  # rootless `podman` as ucorne can't see it — the host `hermes` wrapper
  # shells out to `sudo -n podman exec …` and would otherwise hang on a
  # password prompt. Grant passwordless podman to ucorne. This is
  # effectively passwordless root, but ucorne is already in `wheel`, so it
  # widens nothing meaningful on this single-admin box — it just drops the
  # prompt so the non-interactive `-n` call succeeds.
  security.sudo.extraRules = [{
    users = [ "ucorne" ];
    commands = [{
      command = "/run/current-system/sw/bin/podman";
      options = [ "NOPASSWD" ];
    }];
  }];
}
