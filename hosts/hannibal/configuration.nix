{ config, lib, pkgs, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  # No hardware-configuration.nix — nixos-raspberrypi.nixosModules.raspberry-pi-5.base
  # declares the filesystems (LABEL=NIXOS_SD, LABEL=FIRMWARE), bootloader, kernel,
  # and firmware. That module is wired up in flake.nix.
  imports = [
    ../../system/profiles/base.nix
    ../../system/profiles/server.nix
    ./services/pihole.nix
    ./services/dnscrypt-proxy.nix
  ];

  # ── Filesystems ─────────────────────────────────────────────────────
  # SD-card root + Pi firmware partition. LABELs are baked into the
  # nixos-raspberrypi installer image and survive any rebuild.
  # Options follow the nixos-raspberrypi demo: noatime reduces SD wear,
  # firmware partition automounts on access then idles out.
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [ "noatime" "noauto" "x-systemd.automount" "x-systemd.idle-timeout=1min" ];
    };
  };

  # ── Bootloader ──────────────────────────────────────────────────────
  # Pi 5 uses the "kernel" bootloader (matches the installer image).
  boot.loader.raspberry-pi.bootloader = "kernel";

  # ── Networking ──────────────────────────────────────────────────────
  networking.hostName = "hannibal";
  # useDHCP default is true; LAN router reserves 10.10.10.11 for hannibal.

  # ── Memory ──────────────────────────────────────────────────────────
  # Pi 5 has no swap by default. Needed because tree-sitter grammar builds
  # (pulled in via LazyVim) can transiently spike past physical RAM.
  # Tried zramSwap first but the zram module isn't available in this Pi
  # kernel build — fell back to an on-SD swapfile. SD-card wear from
  # occasional rebuilds is negligible.
  swapDevices = [
    { device = "/swapfile"; size = 4096; }  # MB
  ];

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

  # ── Tailscale ───────────────────────────────────────────────────────
  services.tailscale = {
    useRoutingFeatures = "server"; # ip_forward for advertising routes
    openFirewall = true;           # UDP 41641 for direct connections
    extraSetFlags = [
      "--advertise-routes=10.10.10.0/24"
      "--advertise-exit-node"
    ];
  };

  # ── ZeroTier (LAN backup for Tailscale, disabled by default) ────────
  services.zerotierone = {
    enable = true;
    joinNetworks = [ "db64858fed6d7cac" ];
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [ "zt+" ];   # all zerotier interfaces
    externalInterface = "end0";
  };

  networking.firewall.trustedInterfaces = [ "zt+" ];

  # Install-time release — deliberately NOT bumped when nixos-raspberrypi moves
  # its nixpkgs channel (it's on nixos-26.05 now); this pins stateful defaults.
  system.stateVersion = "25.11";
}
