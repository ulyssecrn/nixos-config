{ config, lib, pkgs, ... }:

{
  # Paperless-ngx — OCR'd document archive. Native module rather than a
  # container: it provisions its own postgres + redis, and its unit is already
  # hardened upstream.
  #
  # Deliberately NOT behind Pangolin. A single index holding bank, tax and
  # government documents is a different risk class from jellyfin or seerr —
  # reachable over LAN/Tailscale via caddy only.
  #
  # Scope of this first cut: direct upload through the web UI. No Nextcloud
  # intake (paperless deletes consumed files behind Nextcloud's back, and its
  # DB only reconciles on `occ files:scan`) and no IMAP ingestion (Proton has
  # no native IMAP, and Bridge on genghis is loopback-bound with no
  # bind-address option). Both are additive later.
  #
  # Sensitive credentials live outside the nix store at:
  #   /var/lib/paperless-secrets/admin-password   (root:root mode 0400)
  #     the web UI superuser password, read by systemd LoadCredential
  # Bootstrap before the first `nrs`:
  #   sudo install -d -m700 /var/lib/paperless-secrets
  #   printf '%s' '<password>' | sudo tee /var/lib/paperless-secrets/admin-password >/dev/null
  #   sudo chmod 400 /var/lib/paperless-secrets/admin-password
  # Also add KUMA_URL_ATILLA_PAPERLESS=<push url> to /var/lib/restic/env, so
  # the new backup job's success heartbeat isn't silently dropped.

  services.paperless = {
    enable = true;

    # caddy fronts it; nothing binds a routable address.
    address = "127.0.0.1";
    port = 28981;

    # Bulk documents on the tank (ZFS, snapshotted) like nextcloud/immich.
    # dataDir stays on the SSD — it holds the search index and postgres-adjacent
    # state, which wants IOPS rather than capacity.
    mediaDir = "/srv/tank/paperless/media";
    consumptionDir = "/srv/tank/paperless/consume";

    database.createLocally = true;
    passwordFile = "/var/lib/paperless-secrets/admin-password";

    settings = {
      # Required behind a reverse proxy — Django rejects the POST otherwise
      # (CSRF origin check + ALLOWED_HOSTS).
      PAPERLESS_URL = "http://paperless.corne.sh";
      PAPERLESS_TIME_ZONE = "Europe/Paris";

      # Single user, so the declarative superuser *is* the daily account.
      # Documents carry an owner and there is no rename path — changing this
      # later creates a second superuser and leaves the old one loginable.
      PAPERLESS_ADMIN_USER = "ucorne";

      # Setting this makes the module override tesseract5's `enableLanguages`,
      # so the first build compiles tesseract from source (not in any cache).
      PAPERLESS_OCR_LANGUAGE = "fra+eng";

      # Paperless names files itself; without a format the media dir is a flat
      # pile of IDs. This keeps it navigable by hand, which is what matters in
      # the case where you're recovering documents *without* a working
      # paperless to ask.
      PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{title}";
    };

    # `document_exporter` output is what actually gets backed up — a
    # self-describing tree (originals + archive + manifest.json) restorable
    # into a fresh instance, unlike a raw copy of mediaDir which is only
    # meaningful alongside a matching database.
    exporter = {
      enable = true;
      directory = "/srv/tank/paperless/export";
      onCalendar = "01:30";   # ahead of the 02:30 restic job below
    };
  };

  # Tank mounts via ZFS, not fstab. The module already sets RequiresMountsFor
  # from its ReadWritePaths, but that alone doesn't order against the import.
  systemd.services = lib.genAttrs [
    "paperless-scheduler"
    "paperless-task-queue"
    "paperless-consumer"
    "paperless-web"
    "paperless-exporter"
  ] (name: {
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
    unitConfig = {
      RequiresMountsFor = "/srv/tank/paperless";
    } // lib.optionalAttrs (name == "paperless-exporter") {
      # The exporter is the sole feed for the backup job, so a silent failure
      # here goes unnoticed until a restore. Same notifier the restic units use.
      OnFailure = [ "restic-failure-notify@%n.service" ];
    };
  });

  systemd.tmpfiles.rules = [
    "d /var/lib/paperless-secrets  0700 root root - -"
    "d /srv/tank/paperless         0750 paperless paperless - -"
    "d /srv/tank/paperless/media   0750 paperless paperless - -"
    "d /srv/tank/paperless/consume 0750 paperless paperless - -"
    "d /srv/tank/paperless/export  0750 paperless paperless - -"
  ];
}
