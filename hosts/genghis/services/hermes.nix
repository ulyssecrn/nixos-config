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

  # ── Tooling for the enabled skills ─────────────────────────────────
  # Skills are prose + scripts; they install NOTHING. And this container can't
  # install Python packages at all: the agent runs as non-root uid 988 so `apt`
  # dies on the dpkg lock, and Ubuntu 24.04 ships no pip and no ensurepip (so
  # even `python3 -m venv` yields a pip-less venv). Only npm/npx work. A doc
  # skill whose script does `import pypdf` is therefore a false affordance —
  # exactly the himalaya failure mode — unless we hand it the interpreter.
  #
  # So: build the interpreter (with the packages those skills import) plus the
  # external binaries they shell out to, and bind-mount this env's bin over
  # /usr/local/bin in the container. That directory is EMPTY in ubuntu:24.04 and
  # already sits ahead of /usr/bin on the container PATH
  # (/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin), so `python3`
  # resolves here with no PATH surgery. /nix/store is fully mounted in the
  # container, so the closure is reachable. Nothing is shadowed and npm still
  # works: its prefix in this image is /usr, not /usr/local.
  #
  # Package list = the actual third-party imports of the enabled skills'
  # scripts, re-derivable with:
  #   grep -rhoE '^(import|from) [a-zA-Z0-9_]+' <skill>/scripts --include='*.py'
  # (`office` / `helpers` in the docx/xlsx/pptx scripts are vendored alongside
  # them, not PyPI.) The two non-Python entries: pdf2image shells out to
  # poppler-utils' pdftoppm/pdfinfo, and tesseract is the OCR engine.
  #
  # Closure is ~1.5GB, and ~1GB of that is tesseract's traineddata (nixpkgs
  # ships every language). Not worth trimming: nixpkgs' pymupdf hardcodes
  # `mupdf.override { enableOcr = true; }`, so the exact same tesseract is in
  # the closure whether or not we list it — listing it just puts the binary on
  # PATH for free. Cutting it would mean overriding mupdf and eating a
  # from-source rebuild of it on every nixpkgs bump, to save disk on the box
  # that stores the GGUFs.
  skillTools = pkgs.buildEnv {
    name = "hermes-skill-tools";
    paths = [
      (pkgs.python312.withPackages (ps: with ps; [
        # pdf. pdfplumber's nativeCheckInputs drag pandas-stubs → tables →
        # blosc2 → torch into the closure, and torch does not build here (nor
        # would we want a multi-GB CUDA-less torch just to read a PDF). Its
        # tests are upstream's, not ours; the runtime deps (pdfminer-six,
        # pillow, pypdfium2) are unaffected by dropping them.
        pypdf
        (pdfplumber.overridePythonAttrs (_: { doCheck = false; nativeCheckInputs = [ ]; }))
        pypdfium2 pdf2image reportlab pillow
        pymupdf pymupdf4llm                # ocr-and-documents
        python-docx openpyxl python-pptx   # docx / xlsx / powerpoint
        defusedxml lxml validators         # shared office/ helpers
      ]))
      pkgs.poppler-utils
      pkgs.tesseract
    ];
    # bin only — we're mounting this ON TOP of /usr/local, so linking share/ or
    # lib/ would drag a nix layout into a place Ubuntu tooling looks at.
    pathsToLink = [ "/bin" ];
  };

  # ── Skills allowlist ───────────────────────────────────────────────
  # Hermes seeds ~/.hermes/skills from the package's share/hermes-agent/
  # {skills,optional-skills} — 77 of them — and injects EVERY enabled skill's
  # name + description into the system prompt on every turn. That's token bloat
  # on a 60-turn budget, but the real cost is false affordances: the `himalaya`
  # skill (IMAP/SMTP from the terminal) had it believing it could read and SEND
  # mail that way, when the only mail wiring on this box is the read-only IMAP
  # MCP above. Same story for the github/* skills (no git or gh in the
  # container), the apple/* ones (no macOS in the fleet) and the delegate-to-
  # another-agent ones (no claude/codex/opencode binary in there).
  #
  # Hermes only understands a `skills.disabled` DENYLIST, so we invert it:
  # skillsEnabled is the allowlist, skillsInventory is everything on disk, and
  # settings.skills.disabled below is the difference. To turn one back on,
  # uncomment its line in skillsEnabled — nothing else to change.
  #
  # Names are the SKILL.md frontmatter `name:`, which is NOT always the
  # directory name (mlops/models/audiocraft → `audiocraft-audio-generation`).
  # Re-derive the inventory after a hermes upgrade with:
  #   find ~/.hermes/skills -name SKILL.md -exec grep -m1 -h '^name:' {} + \
  #     | sed 's/^name:[[:space:]]*//; s/"//g' | sort -u
  # (the preStart drift check further down warns in the journal when it moves).
  #
  # NB `hermes skills` in the TUI writes the same config.yaml key — the module
  # re-renders that file on every start, so TUI toggles are lost on restart.
  # Toggle here, not there.
  skillsEnabled = [
    # Its own docs — configure/theme/extend Hermes. We do a lot of that.
    "hermes-agent"
    # Adapts formatting per surface; we talk to it over Matrix (Element).
    "platform-formatting"
    # The read-only Proton-Bridge IMAP MCP that mcpServers.mail actually wires
    # up. This is the ONLY mail skill that should ever be on here.
    "imap-mini-mcp"
    # Papers in, summaries out. Its script is stdlib-only (urllib + xml), so it
    # runs as-is — no entry in skillTools needed.
    "arxiv"
    # The SKILL.md authoring conventions — this is what Hermes itself followed
    # when it wrote the imap-mini-mcp skill profile above.
    "hermes-agent-skill-authoring"

    # ── Documents (all powered by skillTools, see the `let` above) ────
    # Read/write/manipulate the office+PDF formats. Every one of these is
    # script-driven, so they are only honest with that interpreter mounted —
    # if you ever drop the /usr/local/bin volume, turn these off in the same
    # commit or the agent goes back to claiming it can do things it can't.
    "pdf"              # merge/split/forms/watermarks — pypdf + pdfplumber
    "docx"             # python-docx
    "xlsx"             # openpyxl
    "powerpoint"       # python-pptx
    # Text extraction from PDFs/scans. It documents two backends and we have
    # one: extract_pymupdf.py works, extract_marker.py does NOT — marker-pdf
    # isn't in nixpkgs and it's a 3-5GB PyTorch pipeline we wouldn't want in the
    # closure anyway. OCR of scanned pages still works (mupdf is built with
    # tesseract, so `pixmap.pdfocr_tobytes()` does the job — verified end to end
    # with TESSDATA_PREFIX set below); what's actually lost with marker is the
    # high-accuracy layout work: equations/LaTeX, forms, reading order, header
    # stripping. For anything with a URL its own SKILL.md says to reach for
    # `web_extract` first anyway, which routes through Firecrawl below.
    "ocr-and-documents"

    # ── Methodology (pure prose, no scripts, no deps) ─────────────────
    # Cheap in tokens and they steer it away from thrashing: `plan` makes it
    # write the approach down before touching anything, `spike` is the
    # timeboxed throwaway-investigation pattern for "will this even work".
    "plan"
    "spike"

    # ── Deliberately OFF: the model/inference stack ───────────────────
    # "llama-cpp" and "huggingface-hub" stay off on purpose. Serving and GGUF
    # management are done declaratively in nix (`services.llama-cpp` in this
    # host's configuration.nix, pinned to the club-3090 recipe);
    # an agent narrating hf downloads and llama-server flags would just
    # invent a second, divergent source of truth for something that is
    # already pinned. Same reasoning for serving-llms-vllm.

    # ── Candidates, each blocked on a prerequisite ────────────────────
    # Uncomment once the "needs" is true, otherwise it's another false
    # affordance: the skill is prose, it doesn't install anything. Anything
    # marked "needs py:" also needs its packages added to skillTools above,
    # since the container itself can't install them (see that comment).
    #
    # "claude-code"             # delegate-to-a-coding-agent. The binaries are
    # "opencode"                #   one line away — add pkgs.claude-code /
    #                           #   pkgs.opencode to skillTools and they land on
    #                           #   the container PATH. What's NOT solved is
    #                           #   auth+config: claude-code wants your
    #                           #   subscription creds (~/.claude) or an
    #                           #   ANTHROPIC_API_KEY, opencode wants
    #                           #   ~/.config/opencode. HOME in there is
    #                           #   /home/hermes, backed by /var/lib/hermes/home
    #                           #   on the host — so you'd seed it there, NOT by
    #                           #   bind-mounting your own ~/.claude: that hands
    #                           #   the agent your Anthropic account and defeats
    #                           #   the point of the sandbox. Use a dedicated
    #                           #   key via /var/lib/hermes/env, or leave it off
    #                           #   and keep driving those two from the host
    #                           #   where they already work.
    #                           #   (opencode is easier — point its config at
    #                           #   the local llama.cpp on :8080/v1 like
    #                           #   home/modules/opencode.nix does; no secret.)
    # "systematic-debugging"    # pure-methodology like plan/spike, but it's the
    #                           #   longest of the three — on if you start doing
    #                           #   real debugging IN the container
    # "jupyter-live-kernel"     # needs py: jupyter_client + a running kernel
    # "obsidian"                # needs the vault bind-mounted (container.extraVolumes)
    # "maps"                    # stdlib-only, verified working (`maps_client.py
    #                           #   search "Pittsburgh PA"` hits Nominatim from
    #                           #   inside the container) — off, you don't want it
    # "excalidraw"              # stdlib-only, works today — on if you use excalidraw.com
    # "architecture-diagram"    # prose-only, dark-themed SVG infra diagrams — off
    # "polymarket"              # stdlib-only, works today — prediction markets
    # "research-paper-writing"  # NeurIPS/ICML workflow — on if you're drafting
    # "openhue"                 # needs Hue bridge creds
    # "blogwatcher"             # needs the blogwatcher-cli Go binary
    # "github-auth"             # all 5 github/* need git + gh + a repo volume
    # "github-pr-workflow"
    # "github-code-review"
    # "github-issues"
    # "github-repo-management"
  ];

  # Everything on disk as of hermes-agent 0.19.0. Order is irrelevant
  # (subtractLists), alphabetical for diff sanity. The apple-* four are already
  # filtered out on Linux by their `platforms: [macos]` frontmatter — listed
  # anyway so this stays a faithful mirror of the directory.
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
  #   - the agent can npm-install freely inside that box (the native mode is
  #     immutable and that would fail). NB pip and apt do NOT work in here
  #     either — it runs as non-root uid 988 and the image ships no pip — so
  #     Python tooling has to come from nix; see skillTools above.
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

      # The interpreter + CLIs the enabled document skills need, dropped into
      # the empty /usr/local/bin that already precedes /usr/bin on the container
      # PATH. See the skillTools comment in the `let` above for why this is the
      # only way to get Python packages in here. Read-only: the agent may still
      # install whatever it likes elsewhere (npm's prefix is /usr, untouched),
      # it just can't clobber the toolchain its own skills depend on.
      extraOptions = [ "--volume=${skillTools}/bin:/usr/local/bin:ro" ];
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

      # Skills: allowlist inverted into the denylist Hermes speaks. See the
      # skillsEnabled / skillsInventory comment in the `let` above — that's
      # where you edit, this line never changes.
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
      # Where tesseract's language data lives. Needed because skillTools mounts
      # only the env's bin/ — without this pymupdf's OCR entry points raise
      # "Tesseract is not installed" even though the engine is right there.
      TESSDATA_PREFIX = "${pkgs.tesseract}/share/tessdata";

      SEARXNG_URL = "http://127.0.0.1:8888";
      FIRECRAWL_API_URL = "http://127.0.0.1:3002";
      FIRECRAWL_API_KEY = "self-hosted-no-key-needed";

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

    # Skills drift check. skills.disabled is derived as inventory − enabled, so
    # a skill that ships in a later hermes release is absent from the inventory
    # and therefore NOT disabled — it would quietly switch itself on and put
    # itself back in the system prompt. Warn in the journal instead of failing:
    # a stale list must never crash-loop the gateway.
    # Scans the live skills dir, which the container entrypoint syncs from the
    # store — so after an upgrade the warning lands on the SECOND start, once
    # the new skills are actually on disk.
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
