{ config, lib, pkgs, ... }:

{
  # Reverse proxy for *.corne.sh subdomains, reachable from LAN and Tailscale.
  # The *.corne.sh wildcard resolves to atilla (10.10.10.10) via Cloudflare.
  services.caddy = {
    enable = true;

    virtualHosts = {
      "http://immich.corne.sh".extraConfig      = "reverse_proxy localhost:9080";
      "http://jellyfin.corne.sh".extraConfig    = "reverse_proxy localhost:8096";
      "http://sonarr.corne.sh".extraConfig      = "reverse_proxy localhost:8989";
      "http://radarr.corne.sh".extraConfig      = "reverse_proxy localhost:7878";
      "http://prowlarr.corne.sh".extraConfig    = "reverse_proxy localhost:9696";
      "http://sabnzbd.corne.sh".extraConfig     = "reverse_proxy localhost:8070";
      "http://qbittorrent.corne.sh".extraConfig = "reverse_proxy localhost:8080";
      "http://tracearr.corne.sh".extraConfig    = "reverse_proxy localhost:3000";
      "http://odysseus.corne.sh".extraConfig    = "reverse_proxy 10.10.10.9:7000";
      "http://librechat.corne.sh".extraConfig   = "reverse_proxy 10.10.10.9:3080";
      "http://kuma.corne.sh".extraConfig        = "reverse_proxy 100.105.115.86:3001";
      "http://pihole.corne.sh".extraConfig      = "reverse_proxy 10.10.10.11:80";
      "http://searxng.corne.sh".extraConfig     = "reverse_proxy 10.10.10.9:8888";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
