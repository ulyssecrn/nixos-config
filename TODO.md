# TODO

Single source of truth for pending work and next actions across the fleet
(atilla, genghis, hannibal, loki, odin). Distilled and agent-facing — the
deeper "why" for each item lives in the relevant module's header comment and in
git history.

Convention: keep this current. When an item is done, **delete it** (git is the
record). Add new work here rather than scattering it across other files.


## Active projects

- [ ] **Paperless-ngx on atilla** — deploy a document archive. Decide the
  ingestion path first: a Nextcloud-watched folder vs direct upload. Pick, then
  build the module.
- [ ] **Pictures → Immich** — migrate the large unsorted pictures folder on genghis
  into Immich (atilla). Blocked on the user curating the folder first.
- [ ] **Personal website** — self-hosted developer portfolio on atilla.
  Can now proceed (Pangolin handles public exposure).

## Atilla migrations / ops

- [ ] **Nextcloud off LSIO → native `services.nextcloud`** — the LSIO single
  container (nginx+phpfpm+cron under s6) doesn't recover when phpfpm wedges; the
  current 2-min watchdog only treats the symptom. Real fix is the native module
  (or nextcloud-aio). Bigger lift.
- [ ] **Calibre / calibre-web** — containerize on NixOS. Low priority. Configs
  preserved at `/srv/appdata/{calibre,calibre-web}`.

## AI stack (genghis)

- [ ] **Hermes agent** — trial it (preferred over n8n). Run as a container on
  genghis so it can't touch the host; point it at local llama.cpp (`:8080/v1`).
- [ ] **Firecrawl MCP** — wire `firecrawl-mcp` to the self-hosted instance at
  `http://host.containers.internal:3002` for ad-hoc URL scraping. Not wired yet.
- [ ] **Consider non-vision llama.cpp config for opencode** — current config
  uses club-3090's `mtp-vision` recipe with mmproj-F16 (vision projector) and
  `ctx-size = 150000`, but the fillable ceiling is ~138K before edge OOM. The
  vision projector reserves KV cache that opencode doesn't need. A non-vision
  config (drop `mmproj`, `image-min-tokens`, `image-max-tokens`) would free
  that KV budget, potentially allowing the full 150K context or more for
  opencode conversations. Trade-off: LibreChat loses image upload capability.
  Worth testing if opencode context feels tight during long sessions.

## Watch / blocked (no action unless triggered)

- **Loki CPU stuck at 400 MHz** — the thermald-flag fix FAILED. Next experiment:
  disable TLP and observe. Still need to know whether it hits on AC, battery, or
  both. ThinkPad X1 Gen 13 / Lunar Lake firmware quirk.
- **Loki waybar power-profile toggle** — deferred until the throttle experiment
  resolves; would need TLP → power-profiles-daemon (the two conflict).
- **hyprpolkitagent fingerprint prompt** — renders password-only with a broken
  first submit. Candidate swap: `kdePackages.polkit-kde-agent-1`. Living with it.
- **genghis MCE** — one uncorrected machine-check on 2026-06-16 (looked
  spurious). If a second lands within a month or two, escalate (EXPO→JEDEC, PBO,
  memtest86, PSU under load). One-off → leave alone.
- **electron-39.8.10 whitelist** (`system/profiles/desktop.nix`) — blocked on
  bitwarden-desktop bumping its bundled electron. Passive watch.
- **`programs.ssh.matchBlocks` → `settings` deprecation** — blocked on hannibal
  leaving release-25.11. Don't half-migrate; the warning stays until hannibal
  moves.

## Reliability & CI

- [ ] **flake-bot: prebuild aarch64 hosts** — odin/hannibal are only *eval*-gated
  (genghis is x86_64). To actually cache their closures, add
  `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` on genghis (slow QEMU) and
  build them in `flake-bot.nix`. Deferred — neither has a custom kernel.
- [ ] **Pre-commit linting (statix + alejandra)** — both tools are already
  declared in `home/modules/neovim.nix` but only run inside neovim. Wire them
  up as pre-commit hooks (or a `flake.checks` lint step) so formatting and
  linting is enforced on every commit, not just when editing in neovim.

## Optional repo refactors (only if the duplication bites)

- **LLM model id lives in 4 places** (best payoff) — `Qwen3.6-27B-Q4_K_M.gguf` +
  the genghis endpoint repeat in `hosts/genghis/configuration.nix` (llama-cpp),
  `hosts/genghis/services/librechat.nix`, `home/modules/opencode.nix` (opencode)
  and `home/modules/vscode.nix` (Copilot BYOK). A model bump = 4 edits. Needs a
  flake-level attr or a tiny shared module.
- **LSIO container boilerplate** — `TZ`/`PUID`/`PGID`/`UMASK` +
  `RequiresMountsFor` copy-pasted across ~7 atilla containers.
- **Two fleet IP maps** — `system/profiles/base.nix` (`networking.hosts`) vs
  `home/profiles/base.nix` (ssh `matchBlocks`). Cosmetic; they serve different
  layers (NSS vs ssh).

## Recently shipped (don't re-propose)

- flake-bot — weekly (Sat) auto flake update on genghis, gated on building all
  x86_64 hosts + evaling aarch64, pushes lock only when green, Discord-notified.
  Serves prebuilt closures via nix-serve binary cache; fleet-wide GC + optimise.
- genghis binary cache (`nix-serve` :5000) + cache client trusted fleet-wide.
- atilla: cloudflared removed (Pangolin/newt is the public path); LTS kernel
  pin (ZFS-compat); GPU containers (immich, jellyfin) ordered after the nvidia
  CDI generator so they stop racing it at boot.
- ProtonVPN exit nodes — both live + Kuma-monitored (US on the IONOS VPS, FR as
  nspawn `atilla-proton`).
- Stylix on loki + odin (kitty / gtk / qt / dunst / btop / vscode / opencode).
- restic backups (atilla + genghis), ZFS autoScrub + heartbeat, Kuma wiring.
