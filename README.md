# NixOS Configuration

A declarative, flake-based NixOS configuration managing multiple machines with Home Manager, Hyprland, and a consistent Tokyo Night theme.

## Machines

| Host | Architecture | Hardware | Notes |
|------|-------------|----------|-------|
| **genghis** | x86_64 | Desktop + NVIDIA RTX 3090 Ti | Gaming, VR, CUDA/Ollama |
| **odin** | aarch64 | MacBook Pro M1 Pro (Asahi) | Apple Silicon, AZERTY |
| **loki** | x86_64 | ThinkPad X1 Carbon Gen 13 | Laptop, Intel Xe GPU, fingerprint |

## Structure

```
.
├── flake.nix               # Flake inputs and host definitions
├── system/
│   ├── common.nix          # Shared system config (audio, networking, Hyprland, boot)
│   ├── common_x86.nix      # x86-only packages (gaming, virtualization, Claude CLI)
│   ├── modules/dev.nix     # Development tools (uv)
│   └── overlays.nix        # Nixpkgs overlays
├── home/
│   ├── home.nix            # Shared Home Manager config (packages, Git, SSH, MIME)
│   ├── home_x86.nix        # x86-only home packages (Steam, DaVinci Resolve, Zoom)
│   ├── settings.nix        # Shared variables (wallpaper path)
│   └── modules/            # Hyprland, Neovim, shell, Kitty, theme, Rofi, etc.
└── hosts/
    ├── genghis/            # Nvidia drivers, Steam startup, static IP
    ├── odin/               # Asahi modules, Widevine Firefox, power key suspend
    └── loki/               # Latest kernel, TLP power management, fprintd, HiDPI
```

## Key Software

- **WM**: Hyprland (Wayland) + Waybar + Rofi + Dunst + Hyprlock
- **Terminal**: Kitty + Zsh + Starship
- **Editor**: Neovim via LazyVim (LSP for Nix, Python, C, LaTeX; Copilot; Sidekick AI)
- **Theme**: Tokyo Night across GTK, Kvantum, terminal, lock screen
- **Networking**: Tailscale + ZeroTier One + ProtonVPN
- **Audio**: PipeWire
- **Fonts**: Hack Nerd Font, Noto Sans/Serif/Emoji

## Usage

```bash
# Rebuild and switch (alias)
upgrade

# Update all flake inputs
update

# Manual rebuild for a specific host
sudo nixos-rebuild switch --flake ~/.nixos#<hostname>
```

## Flake Inputs

- `nixpkgs` — `nixos-unstable`
- `home-manager` — `master`
- `nixos-apple-silicon` — Asahi Linux support for odin
- `nixos-hardware` — ThinkPad X1 Carbon hardware profile for loki
- `lazyvim` — [pfassina/lazyvim-nix](https://github.com/pfassina/lazyvim-nix)
