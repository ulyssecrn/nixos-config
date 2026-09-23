{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    brightnessctl
    webex                            # x86_64-only + unfree, so loki-local (not shared desktop.nix; odin is aarch64)
    claude-code-router               # `ccr` — proxy that routes claude-code to other providers; config is user-managed (see below)
  ];

  imports = [
    ../../../home/profiles/base.nix
    ../../../home/profiles/desktop.nix
    ../../../home/profiles/x86/desktop.nix
    ../../../home/modules/herdr.nix
    ../../../home/modules/skills/playwright.nix
    ./modules/hyprland.nix
    ./modules/waybar.nix
  ];
}
