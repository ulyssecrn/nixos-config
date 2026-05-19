{ config, lib, pkgs, ... }:

{
  # Backrest — restic-based backup orchestrator with a web UI on :9898.
  # The Unraid config rsync'd over intact, so the existing config.json,
  # repos, cache, and data dirs are reused. Container paths (/immich,
  # /nextcloud, /appdata, /repos, /cache, /data) are preserved 1:1 so
  # existing plans/repos in config.json still resolve.
  #
  # New additions vs. Unraid setup:
  #   /postgres  → /var/lib/postgresql  (immich DB live files, read-only)
  #   /mysql     → /var/lib/mysql       (nextcloud DB live files, read-only)
  # Live-file backups of DBs aren't crash-safe — for proper backups, add
  # pre-backup hooks in Backrest UI that run pg_dump / mysqldump first.

  virtualisation.oci-containers.containers.backrest = {
    image = "garethgeorge/backrest:latest";
    environment = {
      TZ = "Europe/Paris";
      BACKREST_DATA = "/data";
      BACKREST_CONFIG = "/config/config.json";
      XDG_CACHE_HOME = "/cache";
    };
    volumes = [
      # Backrest's own state (preserved from Unraid)
      "/srv/appdata/backrest:/config:rw"
      "/srv/appdata/backrest/cache:/cache:rw"
      "/srv/appdata/backrest/data:/data:rw"
      "/srv/appdata/backrest/repos:/repos:rw"

      # Backup sources (read-only — paths match the Unraid config.json)
      "/srv/tank/immich:/immich:ro"
      "/srv/tank/nextcloud:/nextcloud:ro"
      "/srv/appdata:/appdata:ro"

      # New backup sources (need plans added via the Backrest UI)
      "/var/lib/postgresql:/postgres:ro"
      "/var/lib/mysql:/mysql:ro"
    ];
    ports = [ "9898:9898" ];
    autoStart = true;
  };

  # Wait for all source mounts before starting — same pattern as immich.
  systemd.services."podman-backrest" = {
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
    unitConfig.RequiresMountsFor = [
      "/srv/tank/immich"
      "/srv/tank/nextcloud"
      "/srv/appdata"
      "/var/lib/postgresql"
      "/var/lib/mysql"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 9898 ];
}
