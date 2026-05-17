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
      "/srv/media:/media:rw"                              # eventual mergerfs view
      "/srv/downloads/usenet:/media/usenet:rw"            # overlay for sabnzbd output
      "/srv/downloads/torrents:/media/torrents:rw"        # overlay for qbit output
    ];
    ports = [ "7878:7878" ];
    autoStart = true;
  };

  systemd.tmpfiles.rules = [
    "d /srv/media 0775 99 100 - -"
  ];

  networking.firewall.allowedTCPPorts = [ 7878 ];
}
