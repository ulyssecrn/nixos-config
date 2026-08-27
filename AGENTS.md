# AGENTS.md

Guidance for AI coding agents (Claude Code, opencode, etc.) working in this
repo. Read this before making changes.

## Repo

Flake-based NixOS config for five hosts. Single repo, per-host configs +
shared profiles/modules. Home Manager is wired through the flake, not a
separate channel.

## Hosts

| Host       | Arch    | Role                                                       |
|------------|---------|------------------------------------------------------------|
| `atilla`   | x86_64  | Storage + services (Jellyfin, Nextcloud, *arr, restic)     |
| `genghis`  | x86_64  | Desktop + NVIDIA 3090 (gaming, VR, local LLM stack)        |
| `hannibal` | aarch64 | Raspberry Pi (Pi-hole, small services)                     |
| `loki`     | x86_64  | ThinkPad X1 Carbon Gen 13 (laptop)                         |
| `odin`     | aarch64 | MacBook Pro M1 Pro (Asahi Linux)                           |

All hosts are on Tailscale. Reverse-proxy through
atilla's Caddy.

## Layout

```
flake.nix                     # mkHost helper + nixosConfigurations
hosts/<host>/
  configuration.nix           # imports + host-specific config
  boot.nix                    # LUKS, initrd SSH unlock, kernel params
  hardware-configuration.nix
  home/                       # per-host home-manager overrides
  services/<svc>.nix          # one file per service
system/profiles/
  base.nix                    # shared system config (all hosts)
  desktop.nix                 # Hyprland-stack hosts
  server.nix                  # headless hosts
  x86/                        # x86-only profiles (gaming, containers, ...)
home/profiles/
  base.nix                    # shared home-manager config
  desktop.nix                 # desktop home additions
home/modules/                 # reusable home-manager modules
system/modules/               # reusable system modules
```

## Service conventions

- One file per service under `hosts/<host>/services/<svc>.nix`, imported
  from that host's `configuration.nix`.
- Containers go through `virtualisation.oci-containers.containers` with
  the `podman` backend (see `system/profiles/x86/containers.nix`).
- Secrets live OUTSIDE the nix store at `/var/lib/<svc>/env`, referenced
  via `environmentFiles = [ "/var/lib/<svc>/env" ];`. Document the
  bootstrap command in the module's header comment.
- Persistent state goes under `/var/lib/<svc>/...` with explicit
  `systemd.tmpfiles.rules` setting ownership (containers commonly run as
  UID 1000 or 999; check the image).
- Reverse proxy entries for genghis-side services live in
  `hosts/atilla/services/caddy.nix` (Caddy runs there, not on genghis).

## Testing changes

```bash
nrs          # alias for: sudo nixos-rebuild switch --flake ~/.nixos#<this-host>
nrt          # alias for: sudo nixos-rebuild test --flake ~/.nixos#<this-host>
```

For cross-host builds:
```bash
sudo nixos-rebuild switch --flake ~/.nixos#<hostname>
```

genghis is a remote build machine for loki (declared via
`nix.buildMachines` with `publicHostKey`). Large rebuilds on loki should
offload automatically.

genghis is also a fleet binary cache (`nix-serve` on `:5000`, trusted via
`nix.settings.trusted-public-keys` in `system/profiles/base.nix`), so other
hosts pull prebuilt closures (e.g. loki's patched kernel) instead of compiling.

`flake.lock` is auto-managed: a weekly `flake-bot` timer on genghis
(`hosts/genghis/services/flake-bot.nix`) runs `nix flake update`, builds all
x86_64 hosts + evals the aarch64 ones as a gate, and pushes only if everything
passes — landing as `[flake] weekly bot auto update` commits on `main`. **Don't
hand-edit `flake.lock`**; let the bot bump inputs, or run `nix flake update` and
verify every host evals first.

## Gotchas (learned the hard way)

- **YAML inside nix `''` strings**: `${VAR}` gets eaten by nix
  interpolation. Escape with `''${VAR}` so the literal `${VAR}` reaches
  the downstream yaml/json parser (e.g., LibreChat env-var
  substitution). This bites for any tool that does its own `${}`
  expansion in config files.
- **`oci-containers` does NOT auto-restart on env-only changes**. After
  changing `environment = {...}` or `environmentFiles`, run
  `sudo systemctl restart podman-<name>` explicitly. `nrs` won't do it.
- **`programs.ssh.matchBlocks` is deprecated on every host now.** It used
  to be the only portable form because hannibal's pinned `release-25.11`
  home-manager had no `programs.ssh.settings`; since hannibal moved to
  `release-26.05` all hosts have `settings` and all warn. The migration
  (whole fleet in one pass, `extraOptions` has no `matchBlocks` equivalent)
  is tracked in `TODO.md`. Until then the warnings are expected.
- **hannibal's home-manager release must track nixos-raspberrypi's nixpkgs
  channel.** `home-manager-stable` in `flake.nix` is pinned to the matching
  `release-XX.YY`; when nixos-raspberrypi bumps its `nixpkgs.url` (it went
  25.11 → 26.05 on 2026-08-01), bump that input in the same commit or
  hannibal's eval breaks on HM/nixpkgs API skew.
- **`boot.initrd.systemd.extraConfig` is deprecated**. Use
  `boot.initrd.systemd.settings.Manager.<key>` instead.
- **Containers share the default podman bridge** with name-based DNS
  (`dns_enabled = true` in `containers.nix`). Inter-container hostnames
  just work; container ↔ host goes via
  `host.containers.internal` (add `--add-host=host.containers.internal:host-gateway`
  to `extraOptions`).
- **podman bridge is IPv4-only** — add `--dns-option=no-aaaa` to any
  container that does DNS lookups, otherwise it'll spend ~5s timing out
  AAAA queries before falling back.
- **LibreChat memory is opt-in** as of recent releases: `memory.agent`
  alone isn't enough, you also need `memory.agent.enabled: true`.
- **CUDA needs `nvidia_uvm` loaded at boot** — Linux doesn't auto-load
  it. Symptom: `ggml_cuda_init: failed to initialize CUDA: unknown
  error` and llama-cpp silently falls back to CPU. Fix:
  `boot.kernelModules = [ "nvidia_uvm" ];` on the NVIDIA host.
- **A driver bump without a reboot also silently falls back to CPU** — a
  second, distinct cause with an identical symptom. `nixos-rebuild` swaps the
  NVIDIA *userspace* libs while the old *kernel module* stays loaded; CUDA
  then refuses to initialise. Tell: `nvidia-smi` prints "Failed to initialize
  NVML: Driver/library version mismatch", and
  `readlink -f /run/{booted,current}-system` differ. Fix is a **reboot**, not
  a kernel module. It hides for as long as a process holds a pre-existing CUDA
  context — genghis served fine for 11 days after the bump and only broke when
  llama-cpp was restarted. Verify a suspect llama.cpp is really on the GPU by
  VRAM delta (`nvidia-smi` before/after load), not by log grep: b10273 prints
  no per-buffer CUDA lines at default verbosity. `hosts/genghis/scripts/try-ctx.sh`
  encodes both checks.

## Things to avoid

- **Never SSH to other machines.** All changes are local-to-repo. If logs or
  remote diagnostics are needed, tell the user the command to run themselves.
- Don't add backwards-compatibility shims for code in this repo — just
  change it. There's no external consumer.
- Don't add comments that restate what the code does. Save comments for
  *why* something non-obvious is the way it is (a workaround, a hidden
  constraint, a learned-the-hard-way pitfall).
- Don't create new markdown docs unless asked. Existing docs:
  `README.md` (this layout), `AGENTS.md` (this file), `TODO.md`.

## Backlog

`TODO.md` (repo root) is the single source of truth for pending work and next
actions. Read it before proposing new work, and keep it current — delete items
as they ship, add new ones there rather than scattering them.
