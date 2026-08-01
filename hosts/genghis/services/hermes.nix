{ config, lib, pkgs, ... }:

let
  # Tokyo Night (dark) TUI skin, matching the fleet Stylix palette in
  # home/modules/stylix.nix. Hermes exposes no NixOS option for skins, so we
  # render the YAML to the store and copy it into ~/.hermes/skins/ in the
  # service preStart (below); `settings.display.skin` then selects it. Skin schema:
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

  # Grayscale "mono" dashboard theme as a USER theme (copied into
  # ~/.hermes/dashboard-themes in preStart) so it can carry customCSS — the
  # stopgap that routes the design-system's display classes (Mondwest serif etc.)
  # through the theme font until upstream PR #57607 lands. Named mono-jb because
  # the built-in `mono` wins name resolution. Fonts come from the dashboard.font
  # override below.
  monoDashboardTheme = pkgs.writeText "mono.yaml" ''
    name: mono-jb
    label: Mono
    palette:
      background: "#0e0e0e"
      midground: "#eaeaea"
      foreground:
        hex: "#ffffff"
        alpha: 0
    layout:
      radius: "0"
    customCSS: |
      .font-mondwest, .font-compressed, .font-expanded, .font-courier {
        font-family: var(--theme-font-display) !important;
      }
  '';

  # CalDAV MCP server for the calendar/tasks toolset — built from pinned, audited,
  # patched source (see the file) instead of npx-from-npm.
  caldav-mcp = pkgs.callPackage ../pkgs/caldav-mcp.nix { };

  # Read-only IMAP MCP for personal mail via Proton Bridge — pinned/audited source,
  # patched down to the 5 read tools (see the file).
  imap-mcp = pkgs.callPackage ../pkgs/imap-mini-mcp.nix { };

  # Interpreter + binaries the document skills' scripts need. The agent runs as
  # non-root uid 988 with no sudo, so it can't apt; the image ships no pip and
  # no ensurepip, so it can't bootstrap one either. Only npm works. Without this
  # env, `pdf`/`docx`/`xlsx`/`powerpoint`/`ocr-and-documents` are prose that
  # can't run — the himalaya failure mode. extraPackages doesn't help: it lands
  # in /etc/profiles/per-user/hermes, which is native-mode only (nixosModules.nix
  # :925 is inside MODE A) and absent from the container's Ubuntu /etc.
  # Package list = the third-party imports of those skills' scripts:
  #   grep -rhoE '^(import|from) [a-zA-Z0-9_]+' <skill>/scripts --include='*.py'
  # ~1.5GB closure, ~1GB of it tesseract traineddata — unavoidable, nixpkgs'
  # pymupdf hardcodes mupdf.override { enableOcr = true; } which pulls the same
  # tesseract whether or not we list it.
  skillTools = pkgs.buildEnv {
    name = "hermes-skill-tools";
    paths = [
      (pkgs.python312.withPackages (ps: with ps; [
        pypdf
        # nativeCheckInputs drag pandas-stubs → tables → blosc2 → torch, which
        # doesn't build here. Runtime deps are unaffected.
        (pdfplumber.overridePythonAttrs (_: { doCheck = false; nativeCheckInputs = [ ]; }))
        pypdfium2 pdf2image reportlab pillow
        pymupdf pymupdf4llm                # ocr-and-documents
        python-docx openpyxl python-pptx   # docx / xlsx / powerpoint
        defusedxml lxml validators         # vendored office/ helpers
      ]))
      pkgs.poppler-utils   # pdftoppm/pdfinfo, shelled out to by pdf2image
      pkgs.tesseract
    ];
    pathsToLink = [ "/bin" ];  # mounted over /usr/local — don't drag share/ or lib/ in
  };

  # Every enabled skill's name + description goes into the system prompt on every
  # turn — token cost, but the real problem is false affordances (himalaya had it
  # believing it could send mail). Hermes only speaks a `skills.disabled`
  # denylist, so we invert: disabled = inventory − enabled, below in settings.
  #
  # Names are the SKILL.md frontmatter `name:`, not always the directory name
  # (mlops/models/audiocraft → audiocraft-audio-generation). Re-derive after an
  # upgrade (the preStart drift check warns when this list goes stale):
  #   find ~/.hermes/skills -name SKILL.md -exec grep -m1 -h '^name:' {} + \
  #     | sed 's/^name:[[:space:]]*//; s/"//g' | sort -u
  #
  # Toggle here, not in the TUI: nix-declared config.yaml keys win on every start.
  skillsEnabled = [
    "hermes-agent"                   # its own docs — we configure it a lot
    "platform-formatting"            # per-surface formatting; we use Matrix
    "imap-mini-mcp"                  # the read-only mail MCP. The ONLY mail skill.
    "arxiv"                          # stdlib-only, runs as-is
    "hermes-agent-skill-authoring"   # SKILL.md conventions

    # Document formats — script-driven, so they depend on skillTools above.
    # Drop that volume and these must come off in the same commit.
    "pdf" "docx" "xlsx" "powerpoint"
    # pymupdf path only; marker-pdf isn't in nixpkgs (3-5GB torch pipeline).
    # OCR still works via mupdf's tesseract; what's lost is marker's layout
    # analysis — equations, forms, reading order.
    "ocr-and-documents"

    "plan" "spike"                   # pure methodology, no deps

    # Deliberately off: llama-cpp, huggingface-hub, serving-llms-vllm. Serving
    # and GGUFs are pinned in this host's configuration.nix; an agent narrating
    # hf downloads would be a second, divergent source of truth.
  ];

  # Everything on disk as of hermes-agent 0.19.0, alphabetical for diff sanity.
  # The apple-* four are already dead on Linux via `platforms:` frontmatter —
  # listed anyway so this mirrors the directory faithfully.
  skillsInventory = [
    "airtable" "apple-notes" "apple-reminders" "architecture-diagram" "arxiv"
    "ascii-art" "ascii-video" "audiocraft-audio-generation" "baoyu-infographic"
    "blogwatcher" "claude-code" "claude-design" "codebase-inspection" "codex"
    "comfyui" "computer-use" "design-md" "docx" "dogfood"
    "evaluating-llms-harness" "excalidraw" "findmy" "gif-search" "github-auth"
    "github-code-review" "github-issues" "github-pr-workflow"
    "github-repo-management" "google-workspace" "heartmula" "hermes-agent"
    "hermes-agent-skill-authoring" "himalaya" "huggingface-hub" "humanizer"
    "imap-mini-mcp" "imessage" "jupyter-live-kernel" "llama-cpp" "llm-wiki"
    "manim-video" "maps" "nano-pdf" "node-inspect-debugger" "notion" "obsidian"
    "ocr-and-documents" "opencode" "openhue" "p5js" "pdf" "petdex" "plan"
    "platform-formatting" "polymarket" "popular-web-designs" "powerpoint"
    "pretext" "python-debugpy" "requesting-code-review" "research-paper-writing"
    "segment-anything-model" "serving-llms-vllm" "simplify-code" "sketch"
    "songsee" "songwriting-and-ai-music" "spike" "systematic-debugging"
    "teams-meeting-pipeline" "test-driven-development" "touchdesigner-mcp"
    "weights-and-biases" "xlsx" "xurl" "youtube-content" "yuanbao"
  ];

  # The inventory as a plain sorted file, for the preStart drift check.
  skillsInventoryFile = pkgs.writeText "hermes-skills-inventory.txt"
    (lib.concatMapStrings (s: s + "\n") skillsInventory);
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
  #   - the agent can npm-install freely inside that box (native mode is
  #     immutable and that would fail). Not pip/apt though: it runs as non-root
  #     uid 988 with no sudo, so Python tooling comes from skillTools above.
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
      extraVolumes = [
        # skillTools over /usr/local/bin — empty in ubuntu:24.04 and already
        # ahead of /usr/bin on PATH, so `python3` resolves to ours with no PATH
        # surgery. Read-only; npm is unaffected (its prefix here is /usr).
        "${skillTools}/bin:/usr/local/bin:ro"
        # A host workspace for project files, if you ever want one:
        # "/srv/hermes/projects:/projects:rw"
      ];
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

      # Edit skillsEnabled in the `let` above; this line never changes.
      skills.disabled = lib.subtractLists skillsEnabled skillsInventory;

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
      # copied into ~/.hermes/skins in preStart below) — recolors the whole
      # TUI to the fleet Stylix palette. Switch live with `/skin`.
      display.skin = "tokyo-night";

      display.pet.enabled = false;

      # Web dashboard: grayscale theme + JetBrains Mono (bundled, no webfont
      # fetch). Persisted to config.yaml — the module re-renders it every start,
      # so this survives restarts (a web-UI pick wouldn't).
      dashboard.theme = "mono-jb";
      dashboard.font = "jetbrains-mono";
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

      # skillTools mounts only bin/, so pymupdf's OCR can't find the language
      # data on its own and raises "Tesseract is not installed".
      TESSDATA_PREFIX = "${pkgs.tesseract}/share/tessdata";

      # Matrix — the Conduit homeserver on atilla. Reached over the LAN (plain
      # http, no TLS/hairpin); the public matrix.corne.sh is only for Element.
      # Auto-enables once MATRIX_ACCESS_TOKEN (in the env file) is also present.
      # ALLOWED_USERS gates inbound to just you. E2EE off (unencrypted room).
      MATRIX_HOMESERVER    = "http://10.10.10.10:6167";
      MATRIX_USER_ID       = "@hermes:matrix.corne.sh";
      MATRIX_ALLOWED_USERS = "@ulysse:matrix.corne.sh";
      # E2EE deliberately off: mautrix's only E2EE backend is python-olm →
      # libolm, which nixpkgs flags insecure (meta.insecure, CVE-2024-4519x)
      # and upstream (Matrix.org) has deprecated as not cryptographically
      # secure. Enabling it needs permittedInsecurePackages — worse than
      # plaintext on our own non-federating single-user box. Revisit if/when
      # mautrix moves to vodozemac. Use an UNENCRYPTED room in Element.
      MATRIX_E2EE_MODE     = "off";
    };

    # ── MCP servers ──────────────────────────────────────────────────
    # Calendar + tasks over CalDAV (Nextcloud). caldav-mcp (dominik1001) on
    # ts-caldav, which implements VTODO properly — the philflowio dav-mcp called
    # a createTodo() that doesn't exist in tsdav, so todo creation always 500'd.
    # Env: CALDAV_BASE_URL + CALDAV_USERNAME/PASSWORD. NB: CALDAV_BASE_URL must be
    # the bare origin (https://nextcloud.corne.sh), NOT .../remote.php/dav —
    # ts-caldav 0.3.7 stores each calendar's raw href path (already /remote.php/dav/…)
    # and axios re-prepends baseURL, so a DAV-suffixed base doubles the path → 404.
    #
    # Built from pinned, audited, patched source (../pkgs/caldav-mcp.nix) rather
    # than npx-ing it live from npm: what runs with your creds is fixed and
    # reviewable, and the patch drops the datetime pattern that broke llama.cpp
    # grammar compilation (400s on any tool call carrying a date). The bash
    # wrapper sources the container .env before exec because MCP stdio spawns get
    # a SANITIZED env (PATH/HOME only) — the gateway's loaded CALDAV_* wouldn't
    # otherwise reach the child; sourcing keeps the creds in the env file (out of
    # the store), whereas an `.env =` here would bake them into config.yaml = store.
    mcpServers.calendar = {
      command = "bash";
      args = [ "-c" "set -a; . /data/.hermes/.env; exec ${caldav-mcp}/bin/caldav-mcp" ];
    };

    # Read-only personal mail over Proton Bridge's local IMAP (127.0.0.1:1143,
    # reached via the container's --network=host). Same env-sourcing wrapper as
    # calendar (sanitized MCP subprocess env). Reads IMAP_HOST/PORT/USER/PASS +
    # the Bridge TLS knobs (IMAP_SECURE/IMAP_STARTTLS/IMAP_TLS_REJECT_UNAUTHORIZED)
    # from the env file; IMAP_PASS is the Bridge-generated password, not your Proton
    # one. The package is patched to expose only read tools (no send/delete/move).
    mcpServers.mail = {
      command = "bash";
      args = [ "-c" "set -a; . /data/.hermes/.env; exec ${imap-mcp}/bin/imap-mini-mcp" ];
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

  # Hermes has no module option for skins. It must be a REAL file, not a
  # /nix/store symlink: the container entrypoint chowns /data/.hermes recursively
  # and a symlink into the read-only store makes that chown fail → crash loop.
  # So copy the store-rendered YAML into the state dir before the container
  # starts (refreshes on every start; the entrypoint then chowns it to hermes).
  systemd.services.hermes-agent.preStart = lib.mkAfter ''
    # rm first: the prior build left a store symlink here, and install would
    # follow it into the read-only store and fail. rm drops only the link.
    ${pkgs.coreutils}/bin/rm -f /var/lib/hermes/.hermes/skins/tokyo-night.yaml
    ${pkgs.coreutils}/bin/install -D -m 0644 ${tokyoNightSkin} \
      /var/lib/hermes/.hermes/skins/tokyo-night.yaml

    ${pkgs.coreutils}/bin/rm -f /var/lib/hermes/.hermes/dashboard-themes/mono.yaml
    ${pkgs.coreutils}/bin/install -D -m 0644 ${monoDashboardTheme} \
      /var/lib/hermes/.hermes/dashboard-themes/mono.yaml

    # Drift check: a skill added by a later hermes release isn't in
    # skillsInventory, so it isn't in the derived denylist, so it silently
    # enables itself. Warn only — a stale list must never crash-loop the
    # gateway. Fires on the SECOND start after an upgrade, once the entrypoint
    # has synced the new skills to disk.
    if [ -d /var/lib/hermes/.hermes/skills ]; then
      found=$(${pkgs.coreutils}/bin/mktemp)
      known=$(${pkgs.coreutils}/bin/mktemp)
      ${pkgs.findutils}/bin/find /var/lib/hermes/.hermes/skills -name SKILL.md \
          -exec ${pkgs.gnugrep}/bin/grep -m1 -h '^name:' {} + \
        | ${pkgs.gnused}/bin/sed 's/^name:[[:space:]]*//; s/"//g' \
        | ${pkgs.coreutils}/bin/sort -u > "$found"
      ${pkgs.coreutils}/bin/sort -u ${skillsInventoryFile} > "$known"
      unknown=$(${pkgs.coreutils}/bin/comm -23 "$found" "$known" | ${pkgs.findutils}/bin/xargs)
      if [ -n "$unknown" ]; then
        echo "hermes: skills NOT in skillsInventory (hermes.nix) and therefore ENABLED by default: $unknown" >&2
      fi
      ${pkgs.coreutils}/bin/rm -f "$found" "$known"
    fi
  '';

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
