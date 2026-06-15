{ config, lib, pkgs, ... }:

{
  # Reverse proxy for *.corne.sh subdomains, accessible over Tailscale only.
  # HTTP only — Tailscale's WireGuard already encrypts traffic end-to-end.

  services.caddy = {
    enable = true;

    virtualHosts = {
      "http://immich.corne.sh".extraConfig   = "reverse_proxy localhost:9080";
      "http://jellyfin.corne.sh".extraConfig = "reverse_proxy localhost:8096";
      "http://sonarr.corne.sh".extraConfig   = "reverse_proxy localhost:8989";
      "http://radarr.corne.sh".extraConfig   = "reverse_proxy localhost:7878";
      "http://prowlarr.corne.sh".extraConfig = "reverse_proxy localhost:9696";
      "http://sabnzbd.corne.sh".extraConfig      = "reverse_proxy localhost:8070";
      "http://qbittorrent.corne.sh".extraConfig     = "reverse_proxy localhost:8080";
      "http://tracearr.corne.sh".extraConfig     = "reverse_proxy localhost:3000";
      "http://odysseus.corne.sh".extraConfig     = "reverse_proxy 10.10.10.9:7000";
      "http://librechat.corne.sh".extraConfig    = "reverse_proxy 10.10.10.9:3080";
    };
  };

  # Tailscale-only — port 80 not opened on LAN/WAN interfaces.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];
}
