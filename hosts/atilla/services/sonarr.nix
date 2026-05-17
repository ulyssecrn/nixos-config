{ config, lib, pkgs, ... }:

{
  virtualisation.oci-containers.containers.sonarr = {
    image = "lscr.io/linuxserver/sonarr:latest";
    environment = {
      TZ = "Europe/Paris";
      PUID = "99";
      PGID = "100";
      UMASK = "022";
    };
    volumes = [
      "/srv/appdata/sonarr:/config:rw"
      "/srv/media:/media:rw"
      "/srv/downloads/usenet:/media/usenet:rw"
      "/srv/downloads/torrents:/media/torrents:rw"
    ];
    ports = [ "8989:8989" ];
    autoStart = true;
  };

  networking.firewall.allowedTCPPorts = [ 8989 ];
}
