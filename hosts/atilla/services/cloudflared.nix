{ config, lib, pkgs, ... }:

{
  # Cloudflare tunnel client. Authenticates with a token; tunnel→service routing
  # is configured on the Cloudflare side, not here.
  #
  # The TUNNEL_TOKEN is sensitive and lives outside the nix store at:
  #   /var/lib/cloudflared/env   (root:root mode 0600)
  # Contents: TUNNEL_TOKEN=eyJh...
  virtualisation.oci-containers.containers.cloudflared = {
    image = "cloudflare/cloudflared:latest";
    cmd = [ "tunnel" "--no-autoupdate" "run" ];
    environment = {
      TUNNEL_METRICS = "127.0.0.1:46495";
      TZ = "Europe/Paris";
    };
    environmentFiles = [ "/var/lib/cloudflared/env" ];
    extraOptions = [ "--network=host" ];
    autoStart = true;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/cloudflared 0700 root root - -"
  ];
}
