{ config, lib, pkgs, ... }:

let
  # Loaded AFTER config.php by the official image (it reads
  # /var/www/html/config/*.config.php in name order), so these win. Everything
  # else — secret, passwordsalt, db creds, mail, 2FA, trusted_domains,
  # overwrite* — stays in the carried-over on-disk config.php, out of the store.
  # Only the bits worth managing declaratively live here:
  #   - Redis for the distributed + file-locking cache. The LSIO install used
  #     APCu for locking, which isn't shared across processes — Redis is the
  #     supported multi-process lock backend.
  #   - trusted_proxies = the podman bridge subnet. Pangolin → WireGuard →
  #     published :8081 means requests reach the container from the podman
  #     gateway (10.88.0.1), not the real client; without this the real client
  #     IP (X-Forwarded-For) is ignored for logging / brute-force.
  overrideConfig = pkgs.writeText "override.config.php" ''
    <?php
    $CONFIG = array (
      'memcache.local' => '\OC\Memcache\APCu',
      'memcache.distributed' => '\OC\Memcache\Redis',
      'memcache.locking' => '\OC\Memcache\Redis',
      'redis' => array (
        'host' => 'nextcloud-redis',
        'port' => 6379,
      ),
      'trusted_proxies' => array (
        0 => '10.88.0.0/16',
      ),
      // First hour (UTC) of the 4h window for heavy daily jobs — ~03:00 Paris.
      'maintenance_window_start' => 2,
    );
  '';

  # Pin the same image for the web and cron containers so they never skew.
  nextcloudImage = "docker.io/library/nextcloud:33.0.7-apache";
in
{
  # Nextcloud on the OFFICIAL nextcloud:*-apache image + MariaDB. Was the
  # linuxserver.io image, which crammed nginx+phpfpm+cron under one s6
  # supervisor and couldn't recover when phpfpm wedged (hence the old
  # nextcloud-watchdog). The official image splits the concerns: apache+phpfpm
  # here, background jobs in nextcloud-cron (/cron.sh), locking/cache in
  # nextcloud-redis — and systemd restart limits replace the watchdog.
  #
  # UID NOTE: unlike LSIO (PUID/PGID env), the official image is hardcoded to
  # www-data = UID 33. The data dir (/srv/tank/nextcloud) and the app/config
  # dirs are owned 33:33. occ runs as `--user www-data`.
  #
  # Sensitive credentials live outside the nix store at:
  #   /var/lib/mariadb/env   (root:root mode 0600)
  #     MYSQL_ROOT_PASSWORD=<root pw>
  #     MYSQL_PASSWORD=<nextcloud user pw>
  #   /srv/appdata/nextcloud-app/config/config.php  (carried over from LSIO;
  #     holds secret / passwordsalt / dbpassword / mail_smtppassword)
  #
  # Pangolin reaches this via the WireGuard site → http://100.89.128.8:8081.

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
      # Bump `nextcloudImage` above to upgrade — the entrypoint runs `occ
      # upgrade` on boot when the image is newer. One MAJOR at a time (NC won't
      # skip); snapshot tank/nextcloud before a major. Never use a floating/
      # latest tag — it'd fire a schema migration at an uncontrolled rebuild.
      image = nextcloudImage;
      environment = {
        TZ = "Europe/Paris";
        PHP_MEMORY_LIMIT = "1024M";
        PHP_UPLOAD_LIMIT = "16G";
      };
      volumes = [
        # App code — image-populated on first boot, on the SSD
        "/srv/appdata/nextcloud-app/html:/var/www/html"
        # config.php (carried over from LSIO) + the Nix override above
        "/srv/appdata/nextcloud-app/config:/var/www/html/config"
        # Existing data on ZFS; datadirectory stays /data
        "/srv/tank/nextcloud:/data"
      ];
      ports = [ "8081:80" ];
      dependsOn = [ "mariadb" "nextcloud-redis" ];
      autoStart = true;
    };

    nextcloud-redis = {
      # Cache + file lock backend; nothing to persist (NC repopulates on restart)
      image = "docker.io/library/redis:7-alpine";
      autoStart = true;
    };

    nextcloud-cron = {
      # Official background-jobs container — runs /cron.sh (php cron.php) every
      # 5 min internally, replacing LSIO's in-container s6 cron.
      image = nextcloudImage;
      entrypoint = "/cron.sh";
      environment = { TZ = "Europe/Paris"; };
      volumes = [
        "/srv/appdata/nextcloud-app/html:/var/www/html"
        "/srv/appdata/nextcloud-app/config:/var/www/html/config"
        "/srv/tank/nextcloud:/data"
      ];
      dependsOn = [ "nextcloud" ];
      autoStart = true;
    };

  };

  # nextcloud + cron bind /srv/tank/nextcloud (ZFS); mariadb binds /var/lib/mysql
  # (btrfs subvol). Each must wait for its mount at boot. StartLimit replaces the
  # old watchdog: 3 failures in 5 min trips a hard stop instead of a re-cold loop.
  systemd.services."podman-nextcloud" = {
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
    unitConfig = {
      RequiresMountsFor = "/srv/tank/nextcloud";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
    };
    serviceConfig.RestartSec = 30;
    # Refresh the Nix-managed override.config.php in the config dir each start.
    preStart = ''
      ${pkgs.coreutils}/bin/install -m644 -o 33 -g 33 \
        ${overrideConfig} /srv/appdata/nextcloud-app/config/override.config.php
    '';
  };
  systemd.services."podman-nextcloud-cron".unitConfig.RequiresMountsFor = "/srv/tank/nextcloud";
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
    # Official-image app + config dirs, owned by www-data (UID 33)
    "d /srv/appdata/nextcloud-app 0750 root root - -"
    "d /srv/appdata/nextcloud-app/html 0750 33 33 - -"
    "d /srv/appdata/nextcloud-app/config 0750 33 33 - -"
  ];

  # Only nextcloud HTTP is LAN-facing; mariadb is bound to 127.0.0.1 above.
  networking.firewall.allowedTCPPorts = [ 8081 ];
}
