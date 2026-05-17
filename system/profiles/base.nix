{ config, lib, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  imports =
    [
      ../modules/dev.nix
      ../overlays.nix
    ];

  # ── Nix Settings ────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "ucorne" ];   # allow remote nixos-rebuild push
  nixpkgs.config.allowUnfree = true;

  # ── Hardware ────────────────────────────────────────────────────────
  # Hardware error logging — useful on desktops and servers alike
  hardware.rasdaemon = {
    enable = true;
    record = true;
  };

  # fwupdmgr
  services.fwupd.enable = true;

  # ── Networking ──────────────────────────────────────────────────────
  services.tailscale.enable = true;
  # the two following lines are to prevent DNS issues with tailscale
  # https://github.com/tailscale/tailscale/issues/4254
  services.resolved.enable = true;
  networking.useNetworkd = false;

  # ── Users ───────────────────────────────────────────────────────────
  users.users.ucorne = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  # ── Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim
    tmux
    wget
    git
    gh
    claude-code
    github-copilot-cli
  ];

  programs.zsh.enable = true;
  programs.direnv.enable = true;
}
