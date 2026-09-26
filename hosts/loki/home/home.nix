{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    brightnessctl
    webex                            # x86_64-only + unfree, so loki-local (not shared desktop.nix; odin is aarch64)
  ];

  imports = [
    ../../../home/profiles/base.nix
    ../../../home/profiles/desktop.nix
    ../../../home/profiles/x86/desktop.nix
    ../../../home/modules/herdr.nix
    ../../../home/modules/claude-code-router.nix
    ../../../home/modules/skills/playwright.nix
    ./modules/hyprland.nix
    ./modules/waybar.nix
  ];
}
