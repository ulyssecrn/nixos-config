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
- [ ] **Self-hosted tunnel** — explore a VPS-based reverse tunnel to replace
  Cloudflare Tunnel (motivated by Jellyfin blocking + latency). Hard constraint:
  family must **not** need Tailscale. Blocks the personal-website work below.
- [ ] **Personal website** — self-hosted developer portfolio on atilla.
  Deferred until the self-hosted tunnel makes public exposure clean.
- [ ] **Delete Notion (~2026-07-11)** — Obsidian-over-Nextcloud is live (loki
  native client + iPhone Remotely Save). Verify sync holds, then delete Notion.

## Atilla migrations / ops

- [ ] **Nextcloud off LSIO → native `services.nextcloud`** — the LSIO single
  container (nginx+phpfpm+cron under s6) doesn't recover when phpfpm wedges; the
  current 2-min watchdog only treats the symptom. Real fix is the native module
  (or nextcloud-aio). Bigger lift.
- [ ] **Calibre / calibre-web** — containerize on NixOS. Low priority. Configs
  preserved at `/srv/appdata/{calibre,calibre-web}`.
- [ ] **Wipe QVO disk (`sdf`)** — decided: wipe. No defined use yet.

## AI stack (genghis)

- [ ] **Hermes agent** — trial it (preferred over n8n). Run as a container on
  genghis so it can't touch the host; point it at local llama.cpp (`:8080/v1`).
- [ ] **Firecrawl MCP** — wire `firecrawl-mcp` to the self-hosted instance at
  `http://host.containers.internal:3002` for ad-hoc URL scraping. Not wired yet.
- [ ] **Retire the open-webui fallback** — LibreChat is the sole chat UI (module
  already removed). Once it's proven stable, drop the kept sqlite fallback.

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

- ProtonVPN exit nodes — both live + Kuma-monitored (US on the IONOS VPS, FR as
  nspawn `atilla-proton`).
- Stylix on loki + odin (kitty / gtk / qt / dunst / btop / vscode / opencode).
- restic backups (atilla + genghis), ZFS autoScrub + heartbeat, Kuma wiring.
