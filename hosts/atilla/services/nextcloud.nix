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
        # cloudflared targets http://localhost:8081
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

  systemd.tmpfiles.rules = [
    "d /var/lib/mariadb 0700 root root - -"
  ];

  # Only nextcloud HTTP is LAN-facing; mariadb is bound to 127.0.0.1 above.
  networking.firewall.allowedTCPPorts = [ 8081 ];
}
