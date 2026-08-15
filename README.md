# NixOS Configuration

Declarative flake-based NixOS config managing five hosts, plus Home Manager,
Hyprland, and a self-hosted LLM stack.

## Machines

| Host       | Arch    | Hardware                         | Role                                                                                              |
|------------|---------|----------------------------------|---------------------------------------------------------------------------------------------------|
| **atilla**   | x86_64  | Server   | ZFS storage, self-hosted cloud (Nextcloud, Immich, Paperless), media library, Caddy reverse proxy, restic backups |
| **genghis**  | x86_64  | Desktop + NVIDIA RTX 3090        | Gaming, VR, local LLM stack (llama.cpp + Qwen3.8, LibreChat, Odysseus, SearXNG, Firecrawl)         |
| **hannibal** | aarch64 | Raspberry Pi                     | Pi-hole DNS                                                                                       |
| **loki**     | x86_64  | ThinkPad X1 Carbon Gen 13        | Laptop, Intel Xe GPU, fingerprint, TLP                                                            |
| **odin**     | aarch64 | MacBook Pro M1 Pro (Asahi Linux) | AZERTY, Widevine Firefox                                                                          |


## Structure

```
flake.nix                     # Flake inputs, mkHost helper, host list
system/
  profiles/                   # Shared system profiles
    base.nix                  # all hosts
    desktop.nix               # Hyprland-stack hosts
    server.nix                # headless hosts
    x86/                      # x86-only (gaming, containers, virtualisation)
  modules/                    # Reusable system modules
  overlays.nix
home/
  profiles/                   # Shared home-manager profiles
    base.nix
    desktop.nix
  modules/                    # Hyprland, Neovim, Kitty, Waybar, etc.
hosts/<host>/
  configuration.nix           # Imports + host-specific config
  boot.nix                    # LUKS, initrd SSH unlock, kernel params
  hardware-configuration.nix
  home/                       # Per-host home-manager overrides
  services/<svc>.nix          # One file per service
```

## Self-hosted services

**On atilla**:

- Media: Jellyfin library + automation stack
- Cloud: Nextcloud (LSIO), Immich, Paperless-ngx (OCR document archive)
- Chat: Conduit (Matrix homeserver)
- Backup: restic → Backblaze B2 (with mariadb-dump timer + Discord/Kuma health notify)
- Proxy: Caddy (Tailscale/LAN); public access via Pangolin (newt connector)

**On genghis** (local LLM stack):

- llama.cpp serving Qwen3.8-27B-Q4_K_M (OpenAI-compat at `:8080`)
- LibreChat — chat UI with memory, web search, RAG (Mongo + pgvector + TEI)
- Odysseus — pewdiepie's alternative chat UI for comparison
- SearXNG — metasearch (host-native at `:8888`)
- Firecrawl — self-hosted web scraper for LibreChat web search

**On hannibal:** Pi-hole.

## Key user-facing software

- **WM**: Hyprland (Wayland) + Waybar + Rofi + Dunst + Hyprlock
- **Terminal**: Kitty + Zsh + Starship
- **Editor**: Neovim via LazyVim (LSP for Nix, Python, C, LaTeX; Copilot; Sidekick AI)
- **Theme**: Tokyo Night across GTK, Kvantum, terminal, lock screen
- **Networking**: Tailscale + ZeroTier + ProtonVPN
- **Audio**: PipeWire

## Usage

```bash
nrs                                                    # rebuild+switch for current host
nrt                                                    # rebuild+test for current host
update                                                 # update all flake inputs
sudo nixos-rebuild switch --flake ~/.nixos#<hostname>  # cross-host build
```

genghis acts as a remote builder for loki (declarative via
`nix.buildMachines` + `publicHostKey`) and as a fleet binary cache
(`nix-serve` on `:5000`, trusted fleet-wide) serving prebuilt closures like
loki's patched kernel. A weekly `flake-bot` timer on genghis auto-updates
`flake.lock` — building every x86_64 host (and evaling the aarch64 ones) as a
gate, pushing only when all pass, Discord-notified either way. Hence the
automated `[flake] weekly bot auto update` commits on `main`.

## Flake inputs

- `nixpkgs` — `nixos-unstable`
- `home-manager` — `master` (most hosts)
- `home-manager-stable` — `release-25.11` (hannibal, pinned to raspberrypi flake)
- `nixos-apple-silicon` — Asahi support for odin
- `nixos-hardware` — laptop profile for loki
- `nixos-raspberrypi` — Pi support for hannibal
- `lazyvim` — [pfassina/lazyvim-nix](https://github.com/pfassina/lazyvim-nix)

## Agent guidance

See [AGENTS.md](AGENTS.md) for conventions, gotchas, and how to make
changes safely.
