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
      # Full /mnt/media1 mounted so *arr can hardlink across
      # /media/torrents -> /media/media/tv.
      # Will become /srv/media:/media once mergerfs is set up.
      "/mnt/media1:/media:rw"
    ];
    ports = [ "8989:8989" ];
    autoStart = true;
  };

  networking.firewall.allowedTCPPorts = [ 8989 ];
}
