{ config, lib, pkgs, ... }:

{
  virtualisation.oci-containers.containers.radarr = {
    image = "lscr.io/linuxserver/radarr:latest";
    environment = {
      TZ = "Europe/Paris";
      PUID = "99";
      PGID = "100";
      UMASK = "022";
    };
    volumes = [
      "/srv/appdata/radarr:/config:rw"
      # Full mergerfs union mounted so *arr can hardlink across
      # /media/torrents -> /media/media/movies (mergerfs places same-branch).
      "/srv/media:/media:rw"
    ];
    ports = [ "7878:7878" ];
    autoStart = true;
  };

  networking.firewall.allowedTCPPorts = [ 7878 ];
}
