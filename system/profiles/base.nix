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
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAsvz9y+oOCCyAFlwfbfXjJ1+NCEsv4Y5G/3ZJ4a75nr" # Odin - Bitwarden
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBYVwIFwG8ODBTvxaUHlvX67GEYfUAMcCrIs1S12URhRurXcK+yaWhjrmJ8wwRdcCU5hfzI7DB+nZEM4Gh41xjs=" # ip17p - Termius
    ];
  };

  # ── Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    gh
    claude-code
    github-copilot-cli
  ];

  programs.zsh.enable = true;
  programs.direnv.enable = true;

  # ── sudo ────────────────────────────────────────────────────────────
  # Preserve the SSH agent socket across sudo so `sudo rsync user@host:…`
  # and similar can reach the forwarded agent without manually passing
  # SSH_AUTH_SOCK on every command.
  security.sudo.extraConfig = ''
    Defaults env_keep += "SSH_AUTH_SOCK"
  '';
}
