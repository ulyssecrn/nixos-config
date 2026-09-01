# TODO

Single source of truth for pending work and next actions across the fleet
(atilla, genghis, hannibal, loki, odin). Distilled and agent-facing — the
deeper "why" for each item lives in the relevant module's header comment and in
git history.

Convention: keep this current. When an item is done, **delete it** (git is the
record). Add new work here rather than scattering it across other files.


## Active projects

- [ ] **Prometheus + Grafana on atilla** — modules written
  (`hosts/atilla/services/monitoring.nix` + fleet-wide
  `system/modules/metrics.nix`), not yet deployed. Three bootstrap steps
  before the first `nrs`, all documented in the module headers: the Grafana
  admin password at `/var/lib/grafana-secrets/admin-password`, the Discord
  webhook at `/var/lib/alertmanager-secrets/env`, and an `nrs` on genghis +
  loki so their exporters come up before atilla starts scraping them.
  Reachable at `grafana.corne.sh` / `prometheus.corne.sh` (Grafana on **3030**,
  not its default 3000 — tracearr owns that port here). Alertmanager stays
  loopback-only. Follow-ups, all additive:
  - *Restic → textfile collector* — `system/modules/metrics.nix` provisions
    `/var/lib/node-exporter-textfile` and enables the collector, but nothing
    writes to it yet. Making `restic-heartbeat@` also drop
    `restic_last_success_timestamp_seconds` there would give backup age as a
    real metric, alertable on staleness, instead of only Kuma's silence
    detection.
  - *rasdaemon alert* — the exporter is on for atilla + genghis, but no rule
    fires on it; the metric names weren't verified against a live instance.
    Read them off `curl localhost:10029/metrics` post-deploy and add a rule, so
    a second uncorrected machine-check pages instead of waiting to be noticed.
  - *ZFS alerting stays with ZED* — the zfs exporter feeds dashboards only.
    Don't duplicate pool-fault notification into Alertmanager.
  - *Not scraped*: ch-vps (Pangolin), us-vps-proton, the pikvms, and the
    `atilla-proton` nspawn. They'd each need node_exporter installed by hand;
    Kuma already covers the two exit nodes.
- [ ] **Paperless-ngx on atilla** — module written
  (`hosts/atilla/services/paperless.nix`), not yet deployed. Ingestion decided:
  **direct upload only**. Bootstrap the admin password (see the module header)
  and add `KUMA_URL_ATILLA_PAPERLESS` to `/var/lib/restic/env` before the first
  `nrs`; expect a from-source tesseract build (`PAPERLESS_OCR_LANGUAGE` triggers
  an `enableLanguages` override that no cache has).
  Deferred by choice, both additive:
  - *Nextcloud intake* — rejected as a folder inside Nextcloud's data dir
    (paperless deletes consumed files behind its back; `oc_filecache` only
    reconciles on `occ files:scan`). If wanted later, do it as External Storage
    (Local) pointed at `consumptionDir` with `filesystem_check_changes`, which
    also needs that path bind-mounted into the nextcloud container and the
    www-data UID 33 / paperless-user split resolved via `consumptionDirIsPublic`.
  - *IMAP ingestion* — Proton has no native IMAP and Bridge on genghis is
    loopback-only with no bind-address flag (confirmed: no `--imap-host`). Path
    is a `systemd-socket-proxyd` on genghis with `BindToDevice = "tailscale0"`
    forwarding to `127.0.0.1:1143`, then a Proton filter routing into a
    `Paperless` folder that one paperless mail rule watches.
- [ ] **French accents on loki's US keyboard** — need a way to type éàèçù without
  giving up the US layout. Options to compare: `us(intl)` / `us(altgr-intl)` as
  the Hyprland `kb_variant` (dead keys vs AltGr combos), or a Compose key via
  `kb_options = "compose:ralt"`. `hosts/loki/home/modules/hyprland.nix` sets no
  `input.kb_*` at all today; odin already does the other approach
  (`kb_layout = "fr,us"` + `grp:shifts_toggle`) if a full layout toggle is
  preferred. Check it doesn't break keybinds that already use AltGr.
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

- [ ] **sabnzbd `configFile` → `settings`** — deprecated, one eval warning. Not
  a rename: `configFile` points the service at the carried-over
  `/srv/appdata/binhex-sabnzbd/sabnzbd.ini` (servers, categories, API key,
  host_whitelist), whereas `settings` makes Nix *generate* the ini, so the whole
  thing has to be transcribed. Credentials must not land in the store — the
  module provides `secretFiles` (ini fragments merged at start, kept outside the
  store like our other `/var/lib/<svc>/env` secrets) and `secretValues`
  (placeholder substitution via `replace-secret`). Keep `allowConfigWrite = true`
  or the web UI goes read-only. Note `configFile`'s default already flips to
  `null` at `stateVersion` 26.05, so this becomes forced on the next major bump —
  atilla is on 25.11.
  No half-measures possible: while `configFile != null` the module short-circuits
  (`publicSettingsIni`/`sabnzbdIniPath` become the file, and the `config_merge.py`
  preStart only exists when it's null), so anything put in `settings` is silently
  ignored — including the module's own defaults. It's one atomic switch.

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

- [ ] **Hermes agent** — DEPLOYED on genghis (podman container mode →
  local llama.cpp; `hosts/genghis/services/hermes.nix`). Trialling it as a
  personal agent. Interaction = the web dashboard (genghis :9119, basic-auth login),
  reverse-proxied by atilla caddy at `hermes.corne.sh` like the other
  services. Messaging: Signal rejected (send-as-you risk on own account,
  dedicated-number friction); no Telegram (cloud). **Matrix is deployed** —
  conduit on atilla (`hosts/atilla/services/matrix.nix`), single-user,
  non-federating, reached from genghis at `http://10.10.10.10:6167`. Remaining
  candidate if alerts are wanted: **ntfy**. See [[reference_hermes_agent_nixos]].
- [ ] **Firecrawl MCP** — Hermes already uses firecrawl as its extraction backend
  (`hermes.nix`, `extract_backend = "firecrawl"`). Still missing: firecrawl-mcp
  wired as a tool for ad-hoc URL scraping, against the self-hosted instance at
  `http://host.containers.internal:3002`.

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
- **`home/modules/herdr.nix` is imported per-host, not from `home/profiles/base.nix`**
  — `programs.herdr` is home-manager **master**-only; it's still absent from
  `release-26.05`, so hannibal's move off 25.11 did NOT unblock this. Fold it
  into base.nix once the module lands on a release branch (or hannibal moves to
  master HM, which nixos-raspberrypi's release-pinned nixpkgs makes unwise).

## Reliability & CI

- [ ] **genghis `nix-serve` wedges and stalls the whole fleet** — observed
  2026-08-31. Symptom: any `nix` command on any host sits at 0% CPU for
  minutes, then prints `unable to download 'http://genghis:5000/<hash>.narinfo':
  Timeout was reached (28) Operation too slow. Less than 1 bytes/sec transferred
  the last 300 seconds`. `nix-serve` still reports `active`; the tell is a pile
  of long-lived `nix ... dump-path` children plus `CLOSE-WAIT` sockets on
  `10.10.10.9:5000` from atilla. Because `system/profiles/base.nix` points every
  host — genghis included — at `http://genghis:5000`, one wedged nix-serve
  blocks *evaluation* fleet-wide, not just downloads.
  `nix.settings.connect-timeout = 5` doesn't help: it bounds the TCP connect,
  not a stalled transfer. Workaround while debugging: append
  `--option substituters 'https://cache.nixos.org'` to bypass it.
  Fixes to weigh: add `nix.settings.stalled-download-timeout` (default 300s is
  what the message is counting) so a wedged cache degrades in seconds; give
  nix-serve a systemd `Restart=` + watchdog; or drop genghis from its *own*
  substituter list, which buys nothing and is what makes this self-inflicted.

- [ ] **flake-bot: prebuild aarch64 hosts** — odin/hannibal are only *eval*-gated
  (genghis is x86_64). To actually cache their closures, add
  `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` on genghis (slow QEMU) and
  build them in `flake-bot.nix`. Deferred — neither has a custom kernel.
- [ ] **Unpin `hermes-agent`** — pinned in `flake.nix` to
  `c2e45b5` (2026-07-27) after the 2026-08-01 flake-bot run failed building
  genghis (see the comment there for the upstream lockfile bug). Since the bot
  reverts `flake.lock` wholesale on any failure, this one broken entry was
  blocking input updates for the *whole fleet*, not just genghis. Drop the pin
  once upstream regenerates their `package-lock.json`; check with
  `curl -sL https://raw.githubusercontent.com/NousResearch/hermes-agent/HEAD/package-lock.json | grep -A3 '"web/node_modules/@nous-research/ui"'`
  — if the entry has a `resolved` field again, it's fixed.
- [ ] **`programs.ssh.matchBlocks` → `settings`** (`home/profiles/base.nix`,
  `home/profiles/desktop.nix`) — **now unblocked.** The old blocker was hannibal
  on `home-manager-stable` = release-25.11, which had no `settings`.
  nixos-raspberrypi moved its nixpkgs to `nixos-26.05` (2026-08-01) and this repo
  followed with `home-manager-stable` → `release-26.05`, which does have
  `programs.ssh.settings` — hannibal now emits the same 5 deprecation warnings as
  every other host. Do the whole fleet in one pass; `extraOptions` goes away in
  the same move (it has no replacement inside `matchBlocks`).
- [ ] **Pre-commit linting (statix + alejandra)** — both tools are already
  declared in `home/modules/neovim.nix` but only run inside neovim. Wire them
  up as pre-commit hooks (or a `flake.checks` lint step) so formatting and
  linting is enforced on every commit, not just when editing in neovim.

## Optional repo refactors (only if the duplication bites)

- **LLM model id lives in 4 places** (best payoff) — `Qwen3.8-27B-UD-IQ4_XS.gguf` +
  the genghis endpoint repeat in `hosts/genghis/configuration.nix` (llama-cpp),
  `hosts/genghis/services/librechat.nix`, `home/modules/opencode.nix` (opencode)
  and `home/modules/vscode.nix` (Copilot BYOK). A model bump = 4 edits. Needs a
  flake-level attr or a tiny shared module.
  Confirmed by the 2026-08-15 3.6→3.8 bump: it was actually 6 files once
  `hermes.nix` (model label) and `README.md` are counted.
- **LSIO container boilerplate** — `TZ`/`PUID`/`PGID`/`UMASK` +
  `RequiresMountsFor` copy-pasted across ~7 atilla containers.
- **Two fleet IP maps** — `system/profiles/base.nix` (`networking.hosts`) vs
  `home/profiles/base.nix` (ssh `matchBlocks`). Cosmetic; they serve different
  layers (NSS vs ssh).
- **Discord → Matrix for notifications** (vague, not scheduled) — consumers are
  `system/modules/restic-notify.nix`, `hosts/genghis/services/flake-bot.nix`,
  `hosts/atilla/services/zed.nix` (slack-format zedlet), plus Sonarr/Radarr and
  Uptime Kuma configured in their own UIs. Only partially sensible: conduit runs
  *on atilla*, so anything that fires while atilla is down (Kuma, restic, ZED)
  must stay on an off-atilla channel — Discord's whole value here is being
  external. Safe to move: flake-bot (genghis, never urgent) and Sonarr/Radarr
  (app events) via their Custom Script notifier. Kuma has native Matrix, the
  curl-based ones are a one-line swap to `/_matrix/client/v3/rooms/{room}/send/
  m.room.message`. Doing the whole lot properly means a homeserver off atilla
  (ch-vps, next to Pangolin). Also verify Element push actually works —
  conduit's push support is its weak spot.

## Recently shipped (don't re-propose)

- hyprlock PAM (`security.pam.services.hyprlock.fprintAuth = false` in
  `system/profiles/desktop.nix`). hyprlock is enabled via home-manager only, which
  can't write `/etc/pam.d`, so it fell back to the `su` stack — every unlock failed
  and *leaked a live hyprlock*, which then made hypridle's `pidof hyprlock` guard
  suppress all later locks (symptom: lid close didn't lock, manual `hyprlock` did).
  Second half of the fix: the CMU krb5 stack must be forced off for hyprlock too
  (`rules.auth.{krb5,ccreds-validate,ccreds-store}.enable = mkForce false`) —
  pam_ccreds' helper binary isn't installed and hyprlock segfaults in
  `CPam::auth()` walking past it, leaking a hyprlock and re-arming the same trap.
  `fprintAuth` must stay **false**: it defaults to `services.fprintd.enable`, and
  hyprlock drives the reader itself via `auth.fingerprint`. Also dropped the
  duplicate `hypridle` from hyprland `exec-once` (both hosts already set
  `services.hypridle.enable`) and added the `pidof` guard to the idle listener.

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
