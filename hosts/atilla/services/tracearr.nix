{ config, lib, pkgs, ... }:

{
  # Tracearr — real-time monitoring for Plex/Jellyfin/Emby. Single container
  # with embedded postgres + redis managed by supervisord, so we just preserve
  # the three data dirs from the Unraid migration.
  #
  # JWT_SECRET / COOKIE_SECRET are left empty to match the Unraid config; the
  # app generates and persists them on first start into /data/tracearr.
  virtualisation.oci-containers.containers.tracearr = {
    image = "ghcr.io/connorgallopo/tracearr:supervised";
    environment = {
      TZ = "Europe/Paris";
      NODE_ENV = "production";
      PORT = "3000";
      HOST = "0.0.0.0";
      LOG_LEVEL = "info";
      CORS_ORIGIN = "*";
      PG_MAX_MEMORY = "2GB";
      DATABASE_URL = "postgresql://tracearr:tracearr@127.0.0.1:5432/tracearr";
      REDIS_URL = "redis://127.0.0.1:6379";
      CA_TS_FALLBACK_DIR = "/data/postgres";
    };
    volumes = [
      "/srv/appdata/tracearr/redis:/data/redis:rw"
      "/srv/appdata/tracearr/data:/data/tracearr:rw"
      "/srv/appdata/tracearr/postgres:/data/postgres:rw"
    ];
    ports = [ "3000:3000" ];
    extraOptions = [
      "--shm-size=512m"  # supervisord-bundled postgres expects shared memory
    ];
    # Weekly registry auto-update (see system/profiles/x86/containers.nix).
    # Accepted risk: the bundled postgres persists at /srv/appdata/tracearr/postgres,
    # so a future image that bumps postgres's MAJOR version will refuse to start
    # on the old cluster (rollback may not catch it if supervisord keeps the
    # container "up" while pg crash-loops). Fine here — tracearr is non-critical
    # and its history is replaceable: if it breaks, pg_upgrade or wipe
    # /srv/appdata/tracearr/postgres and let it reinit.
    labels."io.containers.autoupdate" = "registry";
    autoStart = true;
  };

  networking.firewall.allowedTCPPorts = [ 3000 ];
}
