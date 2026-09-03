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
}
