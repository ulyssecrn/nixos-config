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
in
{
  imports = [ ../../../system/modules/restic-notify.nix ];

  # Three jobs matching the original backrest plans (appdata / immich /
  # nextcloud). Each groups its data with the env file containing that
  # service's secrets — backrest only mounted /srv, so cloudflared /
  # mariadb / immich / qbittorrent env files were not covered.
  #
  # Prune runs separately (monthly) to avoid B2 bandwidth blowup —
  # backrest's prunePolicy was also `0 0 1 * *`.

  services.restic.backups = {
    atilla-appdata = commonRepo // {
      paths = [
        "/srv/appdata"
        "/var/lib/cloudflared/env"
        "/var/lib/qbittorrent/env"
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

    atilla-nextcloud = commonRepo // {
      paths = [
        "/srv/tank/nextcloud/db_backups"
        "/srv/tank/nextcloud/ulyssecrn/files"
        "/var/lib/mariadb/env"
      ];
      extraBackupArgs = [ "--tag" "atilla-nextcloud" ];
      timerConfig = commonTimer "04:00";
    };
  };

  # Wire Discord-failure notifier onto each backup unit + define the
  # monthly prune job. `restic forget --prune --max-unused 10%` against
  # the whole repo, same retention backrest used. --max-unused 10% keeps
  # B2 traffic low (only rewrites pack files when >10% of repo is dead).
  systemd.services = (lib.mapAttrs' (name: _:
    lib.nameValuePair "restic-backups-${name}" {
      unitConfig.OnFailure = [ "restic-failure-notify@%n.service" ];
    }
  ) config.services.restic.backups) // {
    restic-atilla-prune = {
      description = "Restic forget + prune (atilla B2 repo)";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = "/var/lib/restic/env";
      };
      script = ''
        export RESTIC_REPOSITORY=${repoUrl}
        export RESTIC_PASSWORD_FILE=/var/lib/restic/password
        ${pkgs.restic}/bin/restic forget \
          --keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
          --prune --max-unused 10%
      '';
      unitConfig.OnFailure = [ "restic-failure-notify@%n.service" ];
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
}
