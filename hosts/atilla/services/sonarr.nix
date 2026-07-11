{ lib, ... }:

{
  # Sonarr, native (was the lscr.io/linuxserver/sonarr OCI container). LSIO's
  # /config maps onto the module's -data dir: config.xml + sonarr.db + MediaCover
  # + Backups all live at /srv/appdata/sonarr, so pointing dataDir there reuses
  # the DB verbatim (indexers, download clients, series, quality profiles, API
  # key — nothing re-entered). The module isn't sandboxed (ProtectSystem unset),
  # so a dataDir under /srv is fine (unlike the seerr DynamicUser case).
  services.sonarr = {
    enable = true;
    dataDir = "/srv/appdata/sonarr";
    # Primary group `users` (gid 100) + group-writable output so the shared
    # download/library tree stays writable across the now-mixed uids (native
    # sonarr/radarr/sabnzbd + the qbittorrent container, all in gid 100). The
    # LSIO "everything is uid 99" model becomes a shared-gid-100 model.
    group = "users";
  };

  systemd.services.sonarr = {
    serviceConfig.UMask = lib.mkForce "0002";  # module sets 0022; loosen for shared-gid writes
    # Recreate the container's /media (== /srv/media) inside this unit's private
    # namespace so the DB's root folders (/media/media/tv…) and the arr↔download
    # paths (/media/torrents, /media/usenet/complete) resolve with no Remote Path
    # Mapping — qbittorrent (container) and sabnzbd both also speak /media.
    serviceConfig.BindPaths = [ "/srv/media:/media" ];
    unitConfig.RequiresMountsFor = [ "/srv/media" "/srv/appdata/sonarr" ];
  };

  networking.firewall.allowedTCPPorts = [ 8989 ];
}
