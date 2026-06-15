{ config, pkgs, ... }:

let
  # Backblaze B2 via the S3-compat API (recommended over the native b2:
  # backend, which has had upload-reliability issues per restic's own docs).
  bucket = "genghis-restic";
  region = "eu-central-003";
  repoUrl = "s3:s3.${region}.backblazeb2.com/${bucket}";

  dumpsDir = "/var/lib/restic/dumps";
in
{
  imports = [ ../../../system/modules/restic-notify.nix ];

  # /var/lib/restic/env layout (created out-of-band, 0600, root):
  #   AWS_ACCESS_KEY_ID=<B2 keyID>
  #   AWS_SECRET_ACCESS_KEY=<B2 applicationKey>
  #   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
  # /var/lib/restic/password is the restic repo password. Stash a copy in
  # Bitwarden — losing it = unrecoverable B2 data.

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

  systemd.services."restic-backups-genghis" = {
    unitConfig.OnFailure = [ "restic-failure-notify@%n.service" ];
  };
}
