{ config, lib, pkgs, ... }:

{
  virtualisation.oci-containers.containers.sabnzbd = {
    image = "binhex/arch-sabnzbd";
    environment = {
      TZ = "Europe/Paris";
      PUID = "99";
      PGID = "100";
      UMASK = "000";
    };
    volumes = [
      "/srv/appdata/binhex-sabnzbd:/config:rw"
      # Will become /srv/media/usenet once mergerfs is set up.
      "/mnt/media1/usenet:/media/usenet:rw"
    ];
    ports = [
      "8070:8080"   # WebUI (host:8070 -> container:8080, matches Unraid mapping)
      "8090:8090"
    ];
    autoStart = true;
  };

  networking.firewall.allowedTCPPorts = [ 8070 ];
}
