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
- [ ] **Self-host the mesh control plane (Headscale vs NetBird)** — evaluate
  replacing Tailscale's hosted coordination server. Conclusions so far: this
  replaces **Tailscale only, not Pangolin** (public ingress stays). **NetBird**
  = full stack (management + signal + relay + a required IdP, default Zitadel) —
  heaviest, worst lock-out failure mode. **Headscale** = preferred: self-hosts
  the control plane only, keeps the official tailscale clients (just repoint
  `--login-server`), has a `services.headscale` NixOS module, no IdP. Most of
  the Tailscale features it drops (Funnel/Serve, Taildrop, TS-SSH) we already
  solve elsewhere (Pangolin/Cloudflare, LocalSend, own ssh). Exit nodes (the two
  ProtonVPN ones) reproduce as Headscale routes. Runs on ch-vps alongside
  Pangolin; existing tunnels survive if it's down (WG is P2P) — set long key
  expiry to avoid lock-out. Only worth it if the driver is sovereignty; if
  Tailscale is just working, it's a lateral move. Next: sketch the
  `services.headscale` module + one client cutover before committing.

## Atilla migrations / ops

- [ ] **Calibre / calibre-web** — containerize on NixOS. Low priority. Configs
  preserved at `/srv/appdata/{calibre,calibre-web}`.
- [ ] **Jellyfin flickering thumbnails** — some library posters appear then
  disappear/flicker (distinct from the earlier stale-service-worker case where
  images were permanently missing). Flicker = image requests failing
  intermittently. Diagnose: browser F12 → Network, filter `Images`, tick
  *Disable cache*, reproduce, and read the Status column on
  `/Items/<id>/Images/Primary` — all `200` → client/render (SW/cache); `404`/`500`
  → server (missing/corrupt poster on disk, watch `journalctl -u jellyfin -f |
  grep -iE 'error|image|skia'`); `(canceled)`/`(failed)` → transport (likely
  Pangolin HTTP/2 over WG dropping concurrent image streams). Narrow first by:
  does it flicker in a private window too (→ not cache), and LAN vs Pangolin
  (only over Pangolin → tunnel).

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

- **freecad dropped on unstable** (`home/profiles/desktop.nix`) — GDAL 3.13 broke
  the pdal→vtk→freecad build chain: pdal 2.9.3 won't compile against GDAL's new
  const `GetMetadata` API, and gdalMinimal's zarr test also fails
  (nixpkgs#540609, test only). freecad is the sole consumer of that chain
  fleet-wide. Re-add the `freecad` line once nixpkgs ships the gdal/pdal compat
  fix (watch pdal for a patch/bump). No overlay needed after that.

- **loki `/boot` ESP is only 256 MB** (Windows-made, dual-boot). Fixed the
  fill-up that broke `nrs` by lowering `systemd-boot.configurationLimit` 10 → 3
  (each kernel+initrd is ~70 MB; GC never prunes `/boot`, `configurationLimit`
  does). If the 3-generation ceiling ever bites, the clean enlargement is a
  separate **XBOOTLDR** partition carved from the Linux side (leaves the
  BitLocker Windows partitions untouched) — growing `p1` in place is blocked by
  the adjacent BitLocker partition. Live-USB job; not worth it unless it annoys.
- **sabnzbd fully-declarative** (deferred; act only when nixpkgs removes the
  deprecated `configFile`) — we intentionally keep `configFile` pointing at the
  reused binhex `sabnzbd.ini`. Going declarative = translate the ini into
  `services.sabnzbd.settings`, externalize Newshosting creds + API key via
  `secretFiles`, and relocate state `/srv/appdata/binhex-sabnzbd` → `/var/lib/sabnzbd`
  (queue/history). Real work + breakage risk (module option defaults clobber
  port/host/inet_exposure); the deprecation warning is harmless until removal.
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

- immich **2.7.5 → v3.0.2** + all three images pinned to explicit tags (was
  floating `:release`/`:release-cuda`): `immich-server:v3.0.2`,
  `immich-machine-learning:v3.0.2-cuda`, `postgres:16-vectorchord0.4.3-pgvectors0.3.0`.
  Clean bump — already on VectorChord (no pgvecto.rs→VectorChord migration). Both
  immich and nextcloud+mariadb stay OUT of container auto-update: update by hand,
  one step at a time, snapshot first (btrfs cold-copy of `/var/lib/postgresql/immich`
  + `zfs snapshot tank/immich`) — migrations are one-way, snapshot rollback is the
  only way back. Nextcloud can't skip majors.
- sabnzbd + sonarr + radarr → **native** (off LSIO/binhex containers). Pattern:
  point the module `configFile`/`dataDir` at the existing `/srv/appdata/<app>`,
  `group = "users"` + `UMask 0002` for shared-gid-100 hardlinks, bind `/srv/media`
  (or `/srv/media/usenet`) into the unit namespace so the DB/ini's `/media/...`
  paths resolve unchanged, chown config off uid 99. Prowlarr (still in qbit's VPN
  netns) reaches the native arrs at the podman bridge gateway `10.88.0.1`, NOT the
  host LAN IP (hairpin fails); download clients set per-arr at `localhost`, not
  synced from Prowlarr. Remaining containers are deliberate keepers.
- seerr (native `services.seerr`, /var/lib/jellyseerr, backed up via restic).
- Container auto-update (weekly `podman-auto-update.timer` in
  `system/profiles/x86/containers.nix`, opt-in via `io.containers.autoupdate =
  "registry"` label). Labeled: **qbittorrent, prowlarr, tracearr**. tracearr is
  an *accepted risk* — its bundled postgres could break on a major bump, but it's
  non-critical + replaceable (pg_upgrade or wipe `/srv/appdata/tracearr/postgres`
  to fix). Deliberately NOT labeled (critical coupled DBs, update by hand w/
  backup): **immich, nextcloud+mariadb**. prowlarr got `PartOf =
  podman-qbittorrent.service` so it re-joins the netns when a qbit auto-update
  restarts it.

- flake-bot — weekly (Sat) auto flake update on genghis, gated on building all
  x86_64 hosts + evaling aarch64, pushes lock only when green, Discord-notified.
  Serves prebuilt closures via nix-serve binary cache; fleet-wide GC + optimise.
- genghis binary cache (`nix-serve` :5000) + cache client trusted fleet-wide.
- atilla public path: Cloudflare Tunnel → Pangolin (ch-vps), then newt →
  kernel-WireGuard (newt's userspace proxy capped ~7 Mbps; WG ~270 Mbps). LTS
  kernel pin (ZFS-compat); GPU containers (immich, jellyfin) ordered after the
  nvidia CDI generator so they stop racing it at boot.
- Nextcloud off LSIO → official `nextcloud:*-apache` image (web + cron + redis
  containers), watchdog replaced by systemd StartLimit; MariaDB + data kept.
- ProtonVPN exit nodes — both live + Kuma-monitored (US on the IONOS VPS, FR as
  nspawn `atilla-proton`).
- Stylix on loki + odin (kitty / gtk / qt / dunst / btop / vscode / opencode).
- restic backups (atilla + genghis), ZFS autoScrub + heartbeat, Kuma wiring.
  Now self-verifying: weekly `restic check` (structural) + monthly
  `check --read-data-subset=5%` (bitrot) on the shared B2 repo, both wired to the
  failure notifier (`restic.nix`, `mkMaintenance` helper). Restore-drilled
  2026-07-11 — immich `admin/2026` and the full nextcloud snapshot both restored
  byte-identical from B2. NB restore drills must pass `--tag <job>`; the module
  wrappers preset repo+password only, so bare `restore latest` grabs the newest
  snapshot repo-wide (the 04:00 nextcloud one).
