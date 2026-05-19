{ config, lib, pkgs, ... }:

{
  # Backrest — restic-based backup orchestrator with a web UI on :9898.
  # The Unraid config rsync'd over intact, so the existing config.json,
  # repos, cache, and data dirs are reused. Container paths (/immich,
  # /nextcloud, /appdata, /repos, /cache, /data) are preserved 1:1 so
  # existing plans/repos in config.json still resolve.
  #
  # DB backup strategy: NixOS-side. Live DB files aren't crash-safe to
  # restic-snapshot, so dumps run on a schedule and Backrest captures those:
  #   - Immich's built-in postgres dumper → /srv/tank/immich/photos/backups
  #   - mariadb-dump.timer (in nextcloud.nix) → /srv/tank/nextcloud/db_backups
  # Both directories are inside paths the existing Backrest plans cover.

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

      # Backup sources (read-only — paths match the Unraid config.json).
      # We deliberately do NOT mount /var/lib/postgresql or /var/lib/mysql:
      # live DB files aren't crash-safe to restic-snapshot. Instead:
      #   - Immich's built-in postgres dumper writes to /srv/tank/immich/photos/backups
      #     → covered by the existing /immich plan
      #   - A NixOS systemd timer (see nextcloud.nix) dumps MariaDB to
      #     /srv/tank/nextcloud/db_backups → covered by /nextcloud plan
      "/srv/tank/immich:/immich:ro"
      "/srv/tank/nextcloud:/nextcloud:ro"
      "/srv/appdata:/appdata:ro"
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
    ];
  };

  networking.firewall.allowedTCPPorts = [ 9898 ];
}
