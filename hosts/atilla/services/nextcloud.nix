{ config, lib, pkgs, ... }:

{
  # Nextcloud (linuxserver.io image) + MariaDB. Both on podman's default bridge
  # so nextcloud resolves "mariadb" via podman DNS.
  #
  # Sensitive credentials live outside the nix store at:
  #   /var/lib/mariadb/env   (root:root mode 0600)
  # File contents:
  #   MYSQL_ROOT_PASSWORD=<root pw from Unraid>
  #   MYSQL_PASSWORD=<nextcloud user pw from Unraid>

  virtualisation.oci-containers.containers = {

    mariadb = {
      image = "lscr.io/linuxserver/mariadb:latest";
      environment = {
        TZ = "Europe/Paris";
        PUID = "99";
        PGID = "100";
        UMASK = "022";
        MYSQL_DATABASE = "nextcloud";
        MYSQL_USER = "ulyssecrn";
      };
      environmentFiles = [ "/var/lib/mariadb/env" ];
      volumes = [
        # Config (custom.cnf, logs, sockets) — regular CoW btrfs
        "/srv/appdata/mariadb:/config:rw"
        # DB data on @mariadb subvol (nodatacow) — split-bind over /config/databases
        "/var/lib/mysql:/config/databases:rw"
      ];
      ports = [
        # Localhost-only — nextcloud connects via podman DNS, not via host
        "127.0.0.1:3306:3306"
      ];
      autoStart = true;
    };

    nextcloud = {
      image = "lscr.io/linuxserver/nextcloud:latest";
      environment = {
        TZ = "Europe/Paris";
        PUID = "99";
        PGID = "100";
        UMASK = "022";
      };
      volumes = [
        "/srv/appdata/nextcloud:/config:rw"
        "/srv/tank/nextcloud:/data:rw"
      ];
      ports = [
        # Caddy / Pangolin (newt) target http://localhost:8081
        "8081:80"
      ];
      dependsOn = [ "mariadb" ];
      autoStart = true;
    };

  };

  # nextcloud binds /srv/tank/nextcloud (ZFS), mariadb binds /var/lib/mysql
  # (btrfs subvol). Both must wait for their respective mounts at boot.
  systemd.services."podman-nextcloud" = {
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
    unitConfig.RequiresMountsFor = "/srv/tank/nextcloud";
  };
  systemd.services."podman-mariadb".unitConfig.RequiresMountsFor = "/var/lib/mysql";

  # Daily mariadb dump (replaces the old Unraid userscript). Writes
  # timestamped gzipped dumps to /srv/tank/nextcloud/db_backups/, which
  # Backrest's existing /nextcloud plan ships to B2. Retention: 14 days.
  systemd.services.mariadb-dump = {
    description = "Dump MariaDB databases for Backrest to capture";
    after = [ "podman-mariadb.service" ];
    requires = [ "podman-mariadb.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    path = [ pkgs.podman pkgs.gzip pkgs.coreutils pkgs.findutils ];
    script = ''
      set -euo pipefail
      DUMP_DIR=/srv/tank/nextcloud/db_backups
      # YYYYMMDDTHHMMSS — same naming scheme as the old Unraid script so
      # all historical and new dumps sort/list uniformly.
      STAMP=$(date +%Y%m%dT%H%M%S)
      mkdir -p "$DUMP_DIR"
      podman exec mariadb sh -c \
        'mariadb-dump -uroot -p"$MYSQL_ROOT_PASSWORD" \
           --all-databases --single-transaction --quick' \
        | gzip > "$DUMP_DIR/nextcloud-db-$STAMP.sql.gz"
      # Retention: keep last 14 days
      find "$DUMP_DIR" -type f -name 'nextcloud-db-*.sql.gz' -mtime +14 -delete
    '';
  };

  systemd.timers.mariadb-dump = {
    description = "Daily MariaDB dump timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;            # catch up if the host was off at the scheduled time
      RandomizedDelaySec = "30min";  # don't hammer at exactly midnight
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/mariadb 0700 root root - -"
    "d /srv/tank/nextcloud/db_backups 0750 root root - -"
  ];

  # ── Watchdog ────────────────────────────────────────────────────────
  # Probes /status.php every 2 min; 3 consecutive timeouts → restart.
  # Grace window: skips entirely if the container started <10 min ago, so a
  # cold opcache (reboot) or a `:latest` occ-upgrade migration — both
  # legitimately slow — can't trip a restart and start a re-cold loop. Only
  # ever fires on a container that's been up long enough to be truly wedged.
  systemd.services.nextcloud-watchdog = {
    description = "Probe nextcloud and restart if unresponsive";
    after = [ "podman-nextcloud.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      StateDirectory = "nextcloud-watchdog";
    };
    path = [ pkgs.curl pkgs.systemd pkgs.coreutils pkgs.podman ];
    script = ''
      set -uo pipefail
      STATE="$STATE_DIRECTORY/fails"
      [ -f "$STATE" ] || echo 0 > "$STATE"

      STARTED=$(podman inspect -f '{{.State.StartedAt}}' nextcloud 2>/dev/null) || exit 0
      AGE=$(( $(date +%s) - $(date -d "$STARTED" +%s) ))
      if [ "$AGE" -lt 600 ]; then
        echo "container started ''${AGE}s ago — within startup grace, skipping"
        echo 0 > "$STATE"
        exit 0
      fi

      if curl -sf --max-time 30 -o /dev/null http://127.0.0.1:8081/status.php; then
        echo 0 > "$STATE"
        exit 0
      fi

      FAILS=$(($(cat "$STATE") + 1))
      echo "$FAILS" > "$STATE"

      if [ "$FAILS" -ge 3 ]; then
        echo "nextcloud unresponsive for $FAILS consecutive checks — restarting"
        systemctl restart podman-nextcloud.service
        echo 0 > "$STATE"
      else
        echo "nextcloud probe failed ($FAILS/3)"
      fi
    '';
  };

  systemd.timers.nextcloud-watchdog = {
    description = "Run nextcloud watchdog every 2 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "2min";
      AccuracySec = "10s";
    };
  };

  # Only nextcloud HTTP is LAN-facing; mariadb is bound to 127.0.0.1 above.
  networking.firewall.allowedTCPPorts = [ 8081 ];
}
