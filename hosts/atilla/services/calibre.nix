{ config, lib, pkgs, ... }:

{
  # Calibre-Web over the existing Calibre library on /srv/media. Serves the
  # web UI (browse / upload / edit metadata) and, more to the point, an OPDS
  # catalogue at /opds that KOReader on the Kindle subscribes to.
  #
  # Reachability: a Pangolin resource → the WireGuard site at
  # http://10.253.0.4:8083, exactly like Jellyfin / Nextcloud / Matrix.
  # Deliberately NOT in services/caddy.nix: the caddy vhosts exist for names
  # covered by the *.corne.sh wildcard (→ 10.10.10.10), whereas a Pangolin
  # resource gets its own public A record at the VPS, which overrides the
  # wildcard for LAN and Tailscale clients too. A caddy entry here would be
  # dead config — which is why jellyfin, nextcloud and matrix have none.
  #
  # The Pangolin resource must have Pangolin's OWN auth DISABLED. Its login is
  # a browser portal and KOReader's OPDS client can't complete it; calibre-web's
  # own login is the auth boundary instead. Same trade Jellyfin already makes.
  #
  # FIRST BOOT: calibre-web ships a default admin/admin123 account. Change it
  # before the Pangolin resource is created, not after.

  services.calibre-web = {
    enable = true;

    # Module default is ::1 (loopback only). caddy would be fine with that, but
    # Pangolin arrives on the `pangolin` WG interface, not on lo.
    listen.ip = "0.0.0.0";
    listen.port = 8083;

    options = {
      # NB: no spaces in this path. The module passes it through to
      # ReadWritePaths=, which systemd parses as a whitespace-separated list —
      # ".../Calibre Library" would be read as two paths, the second relative,
      # and the unit would fail to start. Hence the rename off the calibre
      # default "Calibre Library". The directory contents are self-describing
      # (metadata.db + per-author dirs, with book paths stored relative), so
      # renaming it costs nothing beyond re-pointing any desktop calibre.
      calibreLibrary = "/srv/media/media/books/library";

      # Upload + convert from the web UI, so routine additions never need the
      # desktop GUI (and so no second machine ever writes to metadata.db —
      # concurrent writers are how a calibre library gets forked or corrupted).
      # enableBookConversion pulls the full calibre package in for
      # ebook-convert; that's a ~1GB closure, which is the price of not having
      # to hand-convert anything.
      enableBookUploading = true;
      enableBookConversion = true;
    };
  };

  # The library lives under the media tree, still owned 99:100 (gid 100 =
  # users) from the LSIO/arr era — same reason jellyfin joins this group.
  # Unlike jellyfin, calibre-web is a WRITER (metadata edits, uploads, and the
  # covers cache it keeps beside the books), so the library tree has to be
  # group-writable, not just group-readable:
  #   sudo chown -R 99:100 /srv/media/media/books/library
  #   sudo chmod -R g+w    /srv/media/media/books/library
  users.users.calibre-web.extraGroups = [ "users" ];

  # /srv/media is a separate mount; without this the unit can start before it
  # is there, fail the ExecStartPre metadata.db check, and burn its restarts.
  systemd.services.calibre-web.unitConfig.RequiresMountsFor = "/srv/media";

  # LAN-facing like the rest of the stack (caddy proxies from this host, and
  # Pangolin reaches it over the WG site). Note the Gerbil pool deliberately
  # sits on 10.253.0.0/20 rather than 100.89.x — see services/wireguard.nix,
  # traffic from 100.64/10 is eaten by Tailscale's ts-input chain before the
  # host firewall ever sees it.
  networking.firewall.allowedTCPPorts = [ 8083 ];

  # ── Daily news ──────────────────────────────────────────────────────
  # Replaces calibre desktop's "Fetch news" scheduler, which calibre-web has
  # no equivalent for (it serves a library, it doesn't build one). The GUI
  # scheduler is only a wrapper around `ebook-convert <recipe>` + an add to
  # the library, so it reduces to a timer.
  #
  # Both recipes are the free editions and declare no `needs_subscription`,
  # so there are no credentials to plumb. If you ever switch to
  # "Le Monde: Édition abonnés", ebook-convert grows --username/--password
  # and those belong in an EnvironmentFile outside the store, not here.
  #
  # Each issue is tagged `News` (so it lands in the tag taxonomy) and filed
  # into a series named after the recipe. The series is what makes retention
  # exact: `series:"=Le Monde"` cannot collide with "Le Monde diplomatique"
  # the way a title substring match would.

  systemd.services.calibre-news =
    let
      # Builtin recipe names, verbatim from `ebook-convert --list-recipes`.
      recipes = [ "Le Monde" "The New York Times" ];
      keep = 3;   # issues retained per recipe
      library = "/srv/media/media/books/library";
      appDb = "/var/lib/calibre-web/app.db";
    in
    {
      description = "Fetch news recipes into the calibre library";
      after = [ "network-online.target" "calibre-web.service" ];
      wants = [ "network-online.target" ];

      path = [ pkgs.calibre pkgs.jq pkgs.sqlite pkgs.coreutils ];

      serviceConfig = {
        Type = "oneshot";
        User = config.services.calibre-web.user;
        Group = config.services.calibre-web.group;
        StateDirectory = "calibre-web";

        # calibre insists on a writable config dir; the calibre-web user is a
        # system user whose home is /var/empty.
        Environment = [
          "HOME=/var/lib/calibre-web"
          "CALIBRE_CONFIG_DIRECTORY=/var/lib/calibre-web/calibre-config"
        ];

        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ library "/var/lib/calibre-web" ];

        # A recipe that 404s or hits a site redesign is routine, and the
        # script already skips past those. Reaching OnFailure means something
        # systemic broke (library gone, calibre unusable) — worth knowing,
        # since a daily job that quietly stops is the failure you notice six
        # weeks late. NB the shared notifier hardcodes "Backup failed" in its
        # Discord message; generalise its wording if that grates.
        RestartSec = 0;
      };

      unitConfig.OnFailure = [ "restic-failure-notify@%n.service" ];
      unitConfig.RequiresMountsFor = library;

      script = ''
        set -euo pipefail

        LIB=${lib.escapeShellArg library}
        APPDB=${lib.escapeShellArg appDb}
        KEEP=${toString keep}

        # The News shelf lives in calibre-web's app.db, not in metadata.db, so
        # it is created here rather than by calibredb. is_public=1 so it shows
        # in OPDS for every user; owner is the lowest-numbered account (admin).
        if [ -z "$(sqlite3 "$APPDB" "SELECT id FROM shelf WHERE name='News' LIMIT 1;")" ]; then
          sqlite3 "$APPDB" "INSERT INTO shelf (uuid,name,is_public,user_id,kobo_sync,created,last_modified) \
            VALUES (lower(hex(randomblob(16))),'News',1,(SELECT MIN(id) FROM user),0,datetime('now'),datetime('now'));"
          echo "created News shelf"
        fi
        SHELF=$(sqlite3 "$APPDB" "SELECT id FROM shelf WHERE name='News' LIMIT 1;")

        WORK=$(mktemp -d)
        trap 'rm -rf "$WORK"' EXIT

        ${lib.concatMapStringsSep "\n" (recipe: ''
          echo "=== ${recipe} ==="
          OUT="$WORK/issue.epub"
          rm -f "$OUT"

          # Builtin recipes resolve by name; no .recipe file on disk needed.
          if ! ebook-convert ${lib.escapeShellArg "${recipe}.recipe"} "$OUT" >/dev/null 2>&1; then
            echo "recipe failed, skipping: ${recipe}" >&2
          else
            # Keep the recipe's own dated title; only tag + series are forced.
            IDS=$(calibredb add "$OUT" --with-library "$LIB" \
                    -T News -s ${lib.escapeShellArg recipe} \
                  | sed -n 's/^Added book ids: //p' | tr -d ' ')

            for id in $(echo "$IDS" | tr ',' ' '); do
              [ -n "$id" ] || continue
              sqlite3 "$APPDB" "INSERT INTO book_shelf_link (book_id,\"order\",shelf,date_added) \
                SELECT $id, \
                  (SELECT COALESCE(MAX(\"order\"),0)+1 FROM book_shelf_link WHERE shelf=$SHELF), \
                  $SHELF, datetime('now') \
                WHERE NOT EXISTS (SELECT 1 FROM book_shelf_link WHERE book_id=$id AND shelf=$SHELF);"
            done
            echo "added ${recipe}: $IDS"
          fi

          # Retention: newest $KEEP by timestamp survive, the rest go.
          # --sort-by defaults to descending, so .[$KEEP:] is exactly the tail.
          STALE=$(calibredb list --with-library "$LIB" \
                    --search ${lib.escapeShellArg ''series:"=${recipe}"''} \
                    --fields id --sort-by timestamp --for-machine \
                  | jq -r ".[$KEEP:][].id" | paste -sd,)

          if [ -n "$STALE" ]; then
            # --permanent: without it calibre moves deletions into .caltrash
            # inside the library, where they accumulate forever. The empty
            # .caltrash scaffolding is still created either way; it just
            # stays empty (verified: 0 files after repeated prunes).
            calibredb remove --permanent "$STALE" --with-library "$LIB"
            # calibredb knows nothing about shelves, so the link rows would be
            # left dangling and calibre-web would render phantom entries.
            sqlite3 "$APPDB" "DELETE FROM book_shelf_link WHERE book_id IN ($STALE);"
            echo "pruned ${recipe}: $STALE"
          fi
        '') recipes}
      '';
    };

  systemd.timers.calibre-news = {
    description = "Daily news fetch into the calibre library";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "06:00";
      Persistent = true;          # catch up if atilla was down at 06:00
      RandomizedDelaySec = "20m";
    };
  };
}
