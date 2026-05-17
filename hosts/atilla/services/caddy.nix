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
      "http://sab.corne.sh".extraConfig      = "reverse_proxy localhost:8070";
      "http://qbit.corne.sh".extraConfig     = "reverse_proxy localhost:8080";
    };
  };

  # Tailscale-only — port 80 not opened on LAN/WAN interfaces.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];
}
