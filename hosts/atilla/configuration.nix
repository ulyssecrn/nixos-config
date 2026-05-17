{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../system/profiles/base.nix
    ../../system/profiles/server.nix
    ../../system/profiles/x86/containers.nix
    ./services/cloudflared.nix
    ./services/sabnzbd.nix
    ./services/qbittorrent.nix
    ./services/radarr.nix
    ./services/sonarr.nix
    ./services/prowlarr.nix
  ];

  # ── Boot & Kernel ───────────────────────────────────────────────────
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # kernelPackages = pkgs.linuxPackages_latest;

    # ZFS support (no pools imported at boot yet — add to extraPools once
    # tank exists on the 4TB drives)
    supportedFilesystems = [ "zfs" ];
    zfs.forceImportRoot = false;
  };

  # Required for ZFS — must match what was used to create any pool
  networking.hostId = "a7711a1a";

  # ── Networking ──────────────────────────────────────────────────────
  networking = {
    hostName = "atilla";
    useDHCP = false;
    interfaces.enp6s0.ipv4.addresses = [{
      address = "10.10.10.10";
      prefixLength = 24;
    }];
    defaultGateway = {
      address = "10.10.10.1";
      interface = "enp6s0";
    };
    nameservers = [ "10.10.10.11" ];  # hannibal pihole
  };

  # ── Locale ──────────────────────────────────────────────────────────
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "fr_FR.UTF-8/UTF-8" ];

  # ── Power Management ────────────────────────────────────────────────
  powerManagement.cpuFreqGovernor = "schedutil";

  # ── NVIDIA 1080 Ti (Pascal — pinned to the 580 LTSB) ────────────────
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false;
    nvidiaSettings = false;
    # NVIDIA dropped Pascal from the current branch around 595; 580 is the
    # last LTSB that still supports it.
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };

  # ── SSH ─────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # ── Users ───────────────────────────────────────────────────────────
  users.users.ucorne = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAsvz9y+oOCCyAFlwfbfXjJ1+NCEsv4Y5G/3ZJ4a75nr" # Odin - Bitwarden
    ];
  };

  # ── Tailscale (base.nix enables it; atilla advertises LAN + exit node)
  services.tailscale = {
    useRoutingFeatures = "server";
    openFirewall = true;
    extraSetFlags = [
      "--advertise-routes=10.10.10.0/24"
      "--advertise-exit-node"
    ];
  };

  # ── System ──────────────────────────────────────────────────────────
  system.stateVersion = "25.11";
}
