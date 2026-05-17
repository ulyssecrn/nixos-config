{ config, lib, pkgs, ... }:

{
  # Prowlarr runs inside qBittorrent's network namespace so its traffic
  # also goes through the VPN. Web UI is served on qbittorrent's IP at
  # port 9696 (the port is exposed by qBittorrent's container, via
  # VPN_INPUT_PORTS=9696 forwarding into the OpenVPN tunnel).
  virtualisation.oci-containers.containers.prowlarr = {
    image = "lscr.io/linuxserver/prowlarr:latest";
    environment = {
      TZ = "Europe/Paris";
      PUID = "99";
      PGID = "100";
      UMASK = "022";
    };
    volumes = [
      "/srv/appdata/prowlarr:/config:rw"
    ];
    extraOptions = [
      "--network=container:qbittorrent"
    ];
    dependsOn = [ "qbittorrent" ];
    autoStart = true;
  };
}
