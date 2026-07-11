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
    labels."io.containers.autoupdate" = "registry";
    autoStart = true;
  };

  # prowlarr borrows qbittorrent's netns, so whenever qbit's container is
  # replaced/restarted (config change, or an auto-update pull) the old netns is
  # gone and prowlarr must re-join the new one. `dependsOn` only gives
  # Requires+After (ordering), not restart propagation — PartOf adds that, so a
  # qbit restart drags prowlarr with it instead of leaving it network-orphaned.
  systemd.services.podman-prowlarr.partOf = [ "podman-qbittorrent.service" ];
}
