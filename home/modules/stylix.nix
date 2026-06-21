# Shared Stylix core: the Tokyo Night palette plus the TUI targets (btop,
# opencode) that apply to both desktop and headless hosts. Imported by the
# desktop profile (loki, odin) and directly by the headless servers (atilla,
# genghis); desktop hosts layer the GUI targets, fonts, wallpaper and cursor on
# top in home/modules/theme.nix. autoEnable = false so nothing is themed
# implicitly.
#
# NOT imported on hannibal: it's pinned to stable home-manager (release-25.11),
# and the unstable Stylix module references HM options that don't exist there
# (e.g. programs.neovim.initLua via its neovim target) — importing it at all
# breaks eval, even with the target disabled. Fold hannibal in once it moves off
# stable. Its btop keeps the bundled tokyo-night via the mkDefault in btop.nix.
#
# stylix.image is deliberately unset: Stylix only needs it when no base16Scheme
# is given (it derives one from the image). We give the scheme inline, so the
# headless hosts (atilla, genghis) need no wallpaper.
{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.stylix.homeModules.stylix ];

  stylix = {
    enable = true;
    polarity = "dark";
    autoEnable = false;

    # Genuine Tokyo Night values (from the old hand-set kitty palette) rather
    # than the base16 `tokyo-night-dark.yaml` approximation — keeps the terminal
    # ANSI colours faithful. Single source of truth: every Stylix target (GUI on
    # the desktops, btop everywhere) derives from here.
    base16Scheme = {
      base00 = "1a1b26"; # bg
      base01 = "16161e"; # darker bg / panels
      base02 = "283457"; # selection
      base03 = "414868"; # comments / bright black
      base04 = "545c7e";
      base05 = "c0caf5"; # fg
      base06 = "a9b1d6";
      base07 = "c0caf5";
      base08 = "f7768e"; # red
      base09 = "ff9e64"; # orange
      base0A = "e0af68"; # yellow
      base0B = "9ece6a"; # green
      base0C = "7dcfff"; # cyan
      base0D = "7aa2f7"; # blue
      base0E = "bb9af7"; # magenta
      base0F = "db4b4b";
    };

    # TUI targets — themed on every Stylix host, including the SSH-only servers.
    # btop and opencode are both installed fleet-wide (via base.nix), so their
    # themes belong in the core rather than the desktop layer. (hannibal has no
    # Stylix, so its opencode just uses the default theme — see the header note.)
    targets = {
      btop.enable = true;
      opencode.enable = true;
    };
  };
}
