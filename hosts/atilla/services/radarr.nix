{ lib, ... }:

{
  # Radarr, native (was the lscr.io/linuxserver/radarr OCI container). Same shape
  # as the Sonarr migration: LSIO's /config == the module's -data dir, so config
  # (config.xml + radarr.db + MediaCover + Backups) under /srv/appdata/radarr is
  # reused verbatim. Not sandboxed, so a /srv dataDir is fine.
  services.radarr = {
    enable = true;
    dataDir = "/srv/appdata/radarr";
    # gid-100 primary group + group-writable output — see sonarr.nix for the
    # shared-gid rationale (mixed native/container uids all in gid 100).
    group = "users";
  };

  systemd.services.radarr = {
    serviceConfig.UMask = lib.mkForce "0002";  # module sets 0022; loosen for shared-gid writes
    # Recreate /media (== /srv/media) in the unit's namespace so the DB's root
    # folders (/media/media/movies…) and download paths resolve unchanged.
    serviceConfig.BindPaths = [ "/srv/media:/media" ];
    unitConfig.RequiresMountsFor = [ "/srv/media" "/srv/appdata/radarr" ];
  };

  networking.firewall.allowedTCPPorts = [ 7878 ];
}
