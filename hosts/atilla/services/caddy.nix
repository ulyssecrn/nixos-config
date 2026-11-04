{ config, lib, pkgs, ... }:

{
  # Reverse proxy for *.corne.sh subdomains, reachable from LAN and Tailscale.
  # The *.corne.sh wildcard resolves to atilla (10.10.10.10) via Cloudflare.
  #
  # environmentFile feeds {$VAR} substitution in the Caddyfile. systemd won't
  # start caddy without it, which takes EVERY vhost down, not just fava's.
  # Bootstrap before the first `nrs` (single quotes: the bcrypt hash is full
  # of `$`):
  #   printf "FAVA_PASSWORD_HASH='%s'\n" "$(nix run nixpkgs#caddy -- hash-password)" \
  #     | sudo install -D -m400 /dev/stdin /var/lib/caddy/env
  services.caddy = {
    enable = true;
    environmentFile = "/var/lib/caddy/env";

    virtualHosts = {
      "http://immich.corne.sh".extraConfig      = "reverse_proxy localhost:9080";
      "http://sonarr.corne.sh".extraConfig      = "reverse_proxy localhost:8989";
      "http://radarr.corne.sh".extraConfig      = "reverse_proxy localhost:7878";
      "http://prowlarr.corne.sh".extraConfig    = "reverse_proxy localhost:9696";
      "http://sabnzbd.corne.sh".extraConfig     = "reverse_proxy localhost:8070";
      "http://qbittorrent.corne.sh".extraConfig = "reverse_proxy localhost:8080";
      "http://tracearr.corne.sh".extraConfig    = "reverse_proxy localhost:3000";
      "http://paperless.corne.sh".extraConfig   = "reverse_proxy localhost:28981";
      "http://odysseus.corne.sh".extraConfig    = "reverse_proxy 10.10.10.9:7000";
      "http://librechat.corne.sh".extraConfig   = "reverse_proxy 10.10.10.9:3080";
      "http://kuma.corne.sh".extraConfig        = "reverse_proxy 100.105.115.86:3001";
      "http://pihole.corne.sh".extraConfig      = "reverse_proxy 10.10.10.11:80";
      "http://searxng.corne.sh".extraConfig     = "reverse_proxy 10.10.10.9:8888";
      "http://hermes.corne.sh".extraConfig      = "reverse_proxy 10.10.10.9:9119";
      "http://grafana.corne.sh".extraConfig     = "reverse_proxy localhost:3030";
      "http://prometheus.corne.sh".extraConfig  = "reverse_proxy localhost:9090";

      # Fava has no auth of its own (services/beancount.nix).
      "http://fava.corne.sh".extraConfig = ''
        basic_auth {
          ucorne {$FAVA_PASSWORD_HASH}
        }
        reverse_proxy localhost:5000
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
