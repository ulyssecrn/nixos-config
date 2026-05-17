{ config, lib, pkgs, ... }:

{
  virtualisation.oci-containers.containers.jellyfin = {
    image = "jellyfin/jellyfin:latest";
    environment = {
      TZ = "Europe/Paris";
      PUID = "99";
      PGID = "100";
      UMASK = "022";
      JELLYFIN_PublishedServerUrl = "10.10.10.10";
      # Legacy nvidia-container-runtime env vars — harmless with CDI, kept
      # for compatibility with whatever Jellyfin internally expects.
      NVIDIA_VISIBLE_DEVICES = "all";
      NVIDIA_DRIVER_CAPABILITIES = "all";
    };
    volumes = [
      # Config (settings, library DB, plugins) preserved from Unraid
      "/srv/appdata/Jellyfin:/config:rw"
      # Cache moved to NVMe for faster thumbnail / transcode session access
      "/srv/appdata/jellyfin-cache:/cache:rw"
      # Library paths matching the existing Jellyfin library configuration.
      # Will become /srv/media/media/* once mergerfs is up.
      "/mnt/media1/media/movies:/data/movies:rw"
      "/mnt/media1/media/movies-fr:/data/movies-fr:rw"
      "/mnt/media1/media/tv:/data/tvshows:rw"
      "/mnt/media1/media/tv-fr:/data/tv-fr:rw"
      "/mnt/media1/media/anime:/data/anime:rw"
    ];
    ports = [
      "8096:8096"      # HTTP WebUI (cloudflared handles TLS upstream)
      "7359:7359/udp"  # Jellyfin client auto-discovery
      "1900:1900/udp"  # DLNA
    ];
    extraOptions = [
      "--device=nvidia.com/gpu=all"  # 1080 Ti via CDI for NVENC/NVDEC
    ];
    autoStart = true;
  };

  systemd.tmpfiles.rules = [
    "d /srv/appdata/jellyfin-cache 0775 99 100 - -"
  ];

  networking.firewall = {
    allowedTCPPorts = [ 8096 ];
    allowedUDPPorts = [ 7359 1900 ];
  };
}
