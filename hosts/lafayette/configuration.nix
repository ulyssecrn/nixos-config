{ config, pkgs, lib, ... }:

{
  # ── Imports ──────────────────────────────────────────────────────────
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ../../system/profiles/base.nix
    ../../system/profiles/server.nix
  ];

  # ── Boot & Kernel ───────────────────────────────────────────────────
  boot = {
    loader.systemd-boot.enable = true;
    loader.systemd-boot.configurationLimit = 10;
    loader.efi.canTouchEfiVariables = true;

    kernelPackages = pkgs.linuxPackages;
  };

  # ── Networking ──────────────────────────────────────────────────────
  # US LAN (Verizon router), 10.20.20.0/24 — renumbered off the router's
  # 192.168.1.0/24 default so it can be advertised whole (see tailscale below).
  # DHCP; the router reserves 10.20.20.10 for lafayette.
  networking.hostName = "lafayette";

  # ── Locale ──────────────────────────────────────────────────────────
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Memory ──────────────────────────────────────────────────────────
  zramSwap.enable = true;

  # ── SSH ─────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # ── Tailscale (base.nix enables it; lafayette advertises LAN + exit node)
  # Keep this LAN off common consumer defaults (192.168.0/1.x): on Linux
  # Tailscale's table 52 is consulted before main, so an --accept-routes
  # client (loki) on any other network using the same range would have that
  # whole LAN, its gateway included, hijacked into the tunnel.
  services.tailscale = {
    useRoutingFeatures = "server";
    openFirewall = true;
    extraSetFlags = [
      "--advertise-routes=10.20.20.0/24"
      "--advertise-exit-node"
      # French LAN 10.10.10.0/24 (atilla/hannibal): the genghis binary cache
      # resolves there, and Kuma will probe French hosts by LAN IP.
      "--accept-routes"
    ];
  };

  # ── Metrics ─────────────────────────────────────────────────────────
  # node exporter + the tailscale0-only firewall rule come from
  # system/modules/metrics.nix. Scraped by atilla over the tailnet
  # (hosts/atilla/services/monitoring.nix).
  services.prometheus.exporters = {
    smartctl.enable = true;
    rasdaemon.enable = true;
  };

  # ── System ──────────────────────────────────────────────────────────
  system.stateVersion = "26.05";
}
