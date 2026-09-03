{ config, pkgs, lib, ... }:

let
  # Reuses the existing B2 repo that backrest had been writing to.
  # The repo password (from backrest's config.json) goes verbatim into
  # /var/lib/restic/password — same encryption, no re-init needed.
  repoUrl = "s3:s3.eu-central-003.backblazeb2.com/atilla-backrest";

  commonRepo = {
    repository = repoUrl;
    passwordFile = "/var/lib/restic/password";
    environmentFile = "/var/lib/restic/env";
    initialize = false;  # repo already exists from backrest
  };

  commonTimer = time: {
    OnCalendar = time;
    Persistent = true;
    RandomizedDelaySec = "15m";
  };

  # prune + check share a shape: oneshot, repo/password/cache exported by hand
  # (the unit has no $HOME and no preset repo like the module's backup wrappers
  # do), retried on transient B2 faults, failures → the Discord/Kuma
  # notifier. Only `command` differs.
  mkMaintenance = { description, command }: {
    inherit description;
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/var/lib/restic/env";
      # Provision /var/cache/restic; the service runs with no $HOME, so
      # without this restic can't locate a cache dir and bails.
      CacheDirectory = "restic";
      # B2 occasionally serves a truncated object. restic exposes no flag to
      # raise its backend retry count, and its per-file circuit breaker
      # (0.17+) turns one exhausted object into "repository is damaged" —
      # a transient fault is indistinguishable from real corruption. So
      # retry twice, an hour apart, before crying wolf. Restart= is legal
      # for oneshot (only always/on-success are not), and a restarting unit
      # never enters `failed`, so OnFailure fires solely once the start
      # limit below is hit, i.e. after the third attempt also fails.
      Restart = "on-failure";
      RestartSec = "1h";
    };
    startLimitIntervalSec = 14400;  # 4h > 3 attempts x 1h, so the limit is reachable
    startLimitBurst = 3;
    script = ''
      export RESTIC_REPOSITORY=${repoUrl}
      export RESTIC_PASSWORD_FILE=/var/lib/restic/password
      export RESTIC_CACHE_DIR="$CACHE_DIRECTORY"
      ${command}
    '';
    unitConfig.OnFailure = [ "restic-failure-notify@%n.service" ];
  };
in
{
  imports = [ ../../../system/modules/restic-notify.nix ];

  # Three jobs matching the original backrest plans (appdata / immich /
  # nextcloud). Each groups its data with the env file containing that
  # service's secrets — backrest only mounted /srv, so the mariadb /
  # immich / qbittorrent env files were not covered.
  #
  # Prune runs separately (monthly) to avoid B2 bandwidth blowup —
  # backrest's prunePolicy was also `0 0 1 * *`.

  services.restic.backups = {
    atilla-appdata = commonRepo // {
      paths = [
        "/srv/appdata"
        # The calibre library. /srv/media is deliberately unbacked — it is
        # re-downloadable — but this one is not: the metadata (series, authors,
        # covers, read state) is hand-curated and would have to be rebuilt by
        # hand. A few hundred MB of epub next to Jellyfin's terabytes, so it
        # rides along with appdata rather than earning its own plan/tag.
        "/srv/media/media/books/library"
        "/var/lib/qbittorrent/env"
        "/var/lib/jellyseerr"  # seerr state (DynamicUser → not under /srv/appdata)
        # calibre-web app.db: users, passwords and SHELVES. Shelves live here,
        # not in the calibre library's metadata.db, so the library path above
        # does not cover them — restoring from that alone would bring the books
        # back with every shelf gone.
        "/var/lib/calibre-web"
        # Grafana users/prefs — the datasource and dashboards are provisioned
        # from Nix, so little here is load-bearing. The secret-key next to it
        # is: without it the credentials encrypted inside grafana.db restore
        # as garbage, and there is no supported way to re-derive it.
        "/var/lib/grafana"
        "/var/lib/grafana-secrets"
      ];
      exclude = [
        "/srv/appdata/redis"
        "/srv/appdata/backrest"
        "/srv/appdata/Jellyfin/cache"
        "/srv/appdata/Jellyfin/log"
        "/srv/appdata/Jellyfin/transcodes"
        "/srv/appdata/Jellyfin/metadata"
      ];
      extraBackupArgs = [ "--tag" "atilla-appdata" ];
      timerConfig = commonTimer "03:00";
    };

    atilla-immich = commonRepo // {
      paths = [
        "/srv/tank/immich/photos/backups"
        "/srv/tank/immich/photos/library"
        "/srv/tank/immich/photos/profile"
        "/var/lib/immich/env"
      ];
      extraBackupArgs = [ "--tag" "atilla-immich" ];
      timerConfig = commonTimer "03:30";
    };

    # Only the exporter's output, not mediaDir — the export is self-describing
    # (manifest.json + originals + archive) and restores into a fresh instance,
    # whereas mediaDir is only meaningful next to a matching database. Runs
    # after the 01:30 export and before the nextcloud job that carries `forget`.
    atilla-paperless = commonRepo // {
      paths = [
        "/srv/tank/paperless/export"
        "/var/lib/paperless-secrets/admin-password"
      ];
      extraBackupArgs = [ "--tag" "atilla-paperless" ];
      timerConfig = commonTimer "02:30";
    };

    atilla-nextcloud = commonRepo // {
      paths = [
        "/srv/tank/nextcloud/db_backups"
        "/srv/tank/nextcloud/ulyssecrn/files"
        "/var/lib/mariadb/env"
      ];
      extraBackupArgs = [ "--tag" "atilla-nextcloud" ];
      timerConfig = commonTimer "04:00";
      # Mirror backrest: forget runs nightly (cheap — index-only), prune
      # runs monthly (expensive — pack rewrites). Forget runs once on the
      # last backup job of the night so all eras are settled; --group-by
      # tags applies the policy globally so this one invocation covers
      # appdata + immich + nextcloud at once.
      backupCleanupCommand = ''
        ${pkgs.restic}/bin/restic forget \
          --group-by tags \
          --keep-daily 7 --keep-weekly 4 --keep-monthly 6
      '';
    };
  };

  # Wire Discord-failure notifier onto each backup unit + define the repo
  # maintenance jobs (prune + check). forget already ran nightly via
  # backupCleanupCommand on atilla-nextcloud. All three act on the single
  # shared B2 repo, so one of each covers appdata + immich + nextcloud.
  systemd.services = (lib.mapAttrs' (name: _:
    lib.nameValuePair "restic-backups-${name}" {
      unitConfig = {
        OnFailure = [ "restic-failure-notify@%n.service" ];
        OnSuccess = [ "restic-heartbeat@${name}.service" ];
      };
    }
  ) config.services.restic.backups) // {
    # Monthly pack-file rewrite to reclaim B2 space. --max-unused 10% keeps it a
    # near-no-op until dead data crosses that threshold (rare with a stable set).
    restic-atilla-prune = mkMaintenance {
      description = "Restic prune (atilla B2 repo) — monthly pack-file rewrite";
      command = "${pkgs.restic}/bin/restic prune --max-unused 10%";
    };

    # Weekly structural check: verifies indexes/trees and that every referenced
    # pack exists. Metadata-only (no pack download) → no meaningful B2 egress.
    restic-atilla-check = mkMaintenance {
      description = "Restic check (atilla B2 repo) — weekly structural verify";
      command = "${pkgs.restic}/bin/restic check";
    };

    # Monthly deep check: additionally downloads 5% of packs and verifies their
    # hashes, catching B2-side bitrot a structural check can't see. 5%/month
    # samples the whole repo over time while keeping egress modest.
    restic-atilla-check-data = mkMaintenance {
      description = "Restic check (atilla B2 repo) — monthly 5% read-data verify";
      command = "${pkgs.restic}/bin/restic check --read-data-subset=5%";
    };
  };

  systemd.timers.restic-atilla-prune = {
    description = "Monthly restic prune (atilla B2 repo)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-01 05:00:00";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  systemd.timers.restic-atilla-check = {
    description = "Weekly restic structural check (atilla B2 repo)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon *-*-* 05:30:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };

  # Mid-month, clear of the 1st-of-month prune.
  systemd.timers.restic-atilla-check-data = {
    description = "Monthly restic read-data check (atilla B2 repo)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-15 05:00:00";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
