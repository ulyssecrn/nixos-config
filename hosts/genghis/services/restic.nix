{ config, pkgs, ... }:

let
  # Backblaze B2 via the S3-compat API (recommended over the native b2:
  # backend, which has had upload-reliability issues per restic's own docs).
  # Adjust region to match the bucket's actual region — visible in B2's
  # "Bucket Details" panel as the endpoint host.
  bucket = "genghis-restic";
  region = "eu-central-003";
  repoUrl = "s3:s3.${region}.backblazeb2.com/${bucket}";

  dumpsDir = "/var/lib/restic/dumps";
in
{
  # /var/lib/restic/env layout (created out-of-band, 0600, root):
  #   AWS_ACCESS_KEY_ID=<B2 keyID>
  #   AWS_SECRET_ACCESS_KEY=<B2 applicationKey>
  #   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
  # /var/lib/restic/password is the restic repo password. Stash a copy in
  # Bitwarden — losing it = unrecoverable B2 data.
  systemd.tmpfiles.rules = [
    "d /var/lib/restic 0700 root root - -"
    "d ${dumpsDir}     0700 root root - -"
  ];

  services.restic.backups.genghis = {
    repository = repoUrl;
    passwordFile = "/var/lib/restic/password";
    environmentFile = "/var/lib/restic/env";
    initialize = true;

    paths = [
      "/var/lib/librechat/env"
      "/var/lib/librechat/uploads"
      "/var/lib/librechat/images"
      "/var/lib/searxng/env"
      "/var/lib/odysseus/env"
      "/var/lib/odysseus/data"
      "/var/lib/firecrawl/env"
      dumpsDir
    ];

    # Live DBs aren't crash-safe to snapshot. Dump first, then restic picks
    # up the dump files from dumpsDir. set -euo pipefail so a dump failure
    # aborts the backup → OnFailure fires Discord instead of silently
    # uploading a stale archive.
    backupPrepareCommand = ''
      set -euo pipefail
      umask 077

      ${pkgs.podman}/bin/podman exec librechat-mongo \
        mongodump --archive --quiet --db=LibreChat \
        > ${dumpsDir}/librechat-mongo.archive

      ${pkgs.podman}/bin/podman exec librechat-vectordb \
        pg_dump -U librechat -d librechat_rag \
        > ${dumpsDir}/librechat-pgvector.sql
    '';

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];

    timerConfig = {
      OnCalendar = "03:15";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };

  # Discord notification on failure. Templated so other restic jobs (or
  # other systemd units) can reuse it via OnFailure=restic-failure-notify@%n.
  systemd.services."restic-backups-genghis" = {
    unitConfig.OnFailure = [ "restic-failure-notify@%n.service" ];
  };

  systemd.services."restic-failure-notify@" = {
    description = "Discord notify on backup failure: %i";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/var/lib/restic/env";
    };
    scriptArgs = "%i";
    script = ''
      tail=$(${pkgs.systemd}/bin/journalctl -u "$1" --no-pager -n 20 -o cat 2>/dev/null || echo "(no journal)")
      ${pkgs.jq}/bin/jq -nc \
        --arg unit "$1" \
        --arg host "$(${pkgs.nettools}/bin/hostname)" \
        --arg tail "$tail" \
        '{content: ":rotating_light: **Backup failed**: \($unit) on \($host)\n```\n\($tail | .[0:1800])\n```"}' \
        | ${pkgs.curl}/bin/curl -fsS -X POST \
            -H "Content-Type: application/json" \
            --data-binary @- \
            "$DISCORD_WEBHOOK_URL" || true
    '';
  };
}
