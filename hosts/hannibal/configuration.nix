{ config, lib, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  # No hardware-configuration.nix — nixos-raspberrypi.nixosModules.raspberry-pi-5.base
  # declares the filesystems (LABEL=NIXOS_SD, LABEL=FIRMWARE), bootloader, kernel,
  # and firmware. That module is wired up in flake.nix.
  imports = [
    ../../system/profiles/base.nix
    ../../system/profiles/server.nix
  ];

  # ── Networking ──────────────────────────────────────────────────────
  networking.hostName = "hannibal";
  # useDHCP default is true; LAN router reserves 10.10.10.11 for hannibal.

  # ── Locale ──────────────────────────────────────────────────────────
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── SSH server ──────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  users.users.ucorne.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAsvz9y+oOCCyAFlwfbfXjJ1+NCEsv4Y5G/3ZJ4a75nr" # Odin - Bitwarden
  ];

  # ── ZeroTier (LAN backup for Tailscale, disabled by default) ────────
  services.zerotierone = {
    enable = true;
    joinNetworks = [ "db64858fed6d7cac" ];
  };

  system.stateVersion = "25.11"; # match nixos-raspberrypi's pinned nixpkgs channel
}
