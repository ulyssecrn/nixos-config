{ lib, ... }:

{
  # sabnzbd, native (was the binhex/arch-sabnzbd OCI container). Config carries
  # over verbatim: sabnzbd.ini + admin/ + logs under /srv/appdata/binhex-sabnzbd
  # map straight onto the native service — the module just runs `sabnzbd -f
  # <configFile>`, so pointing configFile at the existing .ini reuses the whole
  # setup (servers, categories, API key, host_whitelist) with no re-entry.
  #
  services.sabnzbd = {
    enable = true;
    configFile = "/srv/appdata/binhex-sabnzbd/sabnzbd.ini";
    # Run with primary group `users` (gid 100) so completed downloads land
    # group-owned by gid 100 — readable + hardlinkable by the arr containers
    # (which run PGID 100), same as the binhex UMASK=000/PGID=100 setup.
    group = "users";
  };

  systemd.services.sabnzbd.serviceConfig = {
    # group-writable output so the gid-100 arrs can hardlink completed files
    UMask = "0002";
    # recreate the container's download path inside this unit's namespace only
    BindPaths = [ "/srv/media/usenet:/media/usenet" ];
  };

  systemd.services.sabnzbd.unitConfig.RequiresMountsFor = [
    "/srv/media"
    "/srv/appdata/binhex-sabnzbd"
  ];

  # WebUI on :8070 (set `port` = 8070 in sabnzbd.ini)
  networking.firewall.allowedTCPPorts = [ 8070 ];
}
