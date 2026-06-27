{ config, lib, pkgs, ... }:

{
  # Immich photo management stack — 4 containers on podman's default bridge:
  #   immich_server, immich_machine_learning, immich_postgres, immich_redis
  # Container names use underscores to match the original compose (so
  # immich_server resolves immich_postgres / immich_redis / immich_machine_learning
  # via podman's built-in DNS).
  #
  # Sensitive credentials live outside the nix store at:
  #   /var/lib/immich/env   (root:root mode 0600)
  # File contents:
  #   DB_PASSWORD=<the immich db password>
  #   POSTGRES_PASSWORD=<same value as DB_PASSWORD>
  #   REDIS_PASSWORD=<the redis password>

  virtualisation.oci-containers.containers = {

    immich_postgres = {
      image = "ghcr.io/immich-app/postgres:16-vectorchord0.3.0-pgvectors0.3.0";
      environment = {
        POSTGRES_USER = "postgres";
        POSTGRES_DB = "immich";
        TZ = "Europe/Paris";
      };
      environmentFiles = [ "/var/lib/immich/env" ];
      volumes = [
        # Postgres data on the @postgres btrfs subvolume (nodatacow).
        # Pre-populate from /srv/appdata/postgresql_immich before first start.
        "/var/lib/postgresql/immich:/var/lib/postgresql/data:rw"
      ];
      autoStart = true;
    };

    immich_redis = {
      image = "bitnami/redis:latest";
      environment = {
        REDIS_DBINDEX = "0";
        REDIS_EXTRA_FLAGS = "--auto-aof-rewrite-percentage 100 --auto-aof-rewrite-min-size 64mb";
        ALLOW_EMPTY_PASSWORD = "no";
        TZ = "Europe/Paris";
      };
      environmentFiles = [ "/var/lib/immich/env" ];
      volumes = [
        "/srv/appdata/redis:/bitnami/redis:rw"
      ];
      autoStart = true;
    };

    immich_machine_learning = {
      image = "ghcr.io/immich-app/immich-machine-learning:release-cuda";
      environment = {
        NVIDIA_VISIBLE_DEVICES = "all";
        NVIDIA_DRIVER_CAPABILITIES = "all";
        TZ = "Europe/Paris";
      };
      volumes = [
        "/srv/tank/immich/config/machine-learning:/cache:rw"
      ];
      extraOptions = [
        "--device=nvidia.com/gpu=all"
      ];
      autoStart = true;
    };

    immich_server = {
      image = "ghcr.io/immich-app/immich-server:release";
      environment = {
        TZ = "Europe/Paris";
        DB_HOSTNAME = "immich_postgres";
        DB_PORT = "5432";
        DB_USERNAME = "postgres";
        DB_DATABASE_NAME = "immich";
        REDIS_HOSTNAME = "immich_redis";
        REDIS_PORT = "6379";
        IMMICH_MACHINE_LEARNING_URL = "http://immich_machine_learning:3003";
        NVIDIA_VISIBLE_DEVICES = "all";
        NVIDIA_DRIVER_CAPABILITIES = "all";
      };
      environmentFiles = [ "/var/lib/immich/env" ];
      volumes = [
        "/srv/tank/immich/photos:/usr/src/app/upload:rw"
        "/etc/localtime:/etc/localtime:ro"
      ];
      ports = [ "9080:2283" ];
      dependsOn = [ "immich_postgres" "immich_redis" "immich_machine_learning" ];
      extraOptions = [
        "--device=nvidia.com/gpu=all"
      ];
      autoStart = true;
    };

  };

  # Ordering deps for the two GPU containers:
  #  - zfs-mount.service: tank mounts via ZFS, not fstab (RequiresMountsFor
  #    covers the path; the explicit dep ensures import+mount happen first).
  #  - nvidia-container-toolkit-cdi-generator.service: generates the
  #    `nvidia.com/gpu=all` CDI spec. Without ordering after it, on a fresh
  #    boot the container starts before the spec exists and dies with
  #    "unresolvable CDI devices nvidia.com/gpu=all" (exit 126). ML has a
  #    Restart and recovers, but immich_server (Requires=ML) aborts during
  #    that window and never retries — needing a manual start every boot.
  systemd.services."podman-immich_server" = {
    after = [ "zfs-mount.service" "nvidia-container-toolkit-cdi-generator.service" ];
    requires = [ "zfs-mount.service" "nvidia-container-toolkit-cdi-generator.service" ];
    unitConfig.RequiresMountsFor = "/srv/tank/immich";
  };
  systemd.services."podman-immich_machine_learning" = {
    after = [ "zfs-mount.service" "nvidia-container-toolkit-cdi-generator.service" ];
    requires = [ "zfs-mount.service" "nvidia-container-toolkit-cdi-generator.service" ];
    unitConfig.RequiresMountsFor = "/srv/tank/immich";
  };
  systemd.services."podman-immich_postgres".unitConfig.RequiresMountsFor =
    "/var/lib/postgresql";

  systemd.tmpfiles.rules = [
    "d /var/lib/immich 0700 root root - -"
  ];

  networking.firewall.allowedTCPPorts = [ 9080 ];
}
