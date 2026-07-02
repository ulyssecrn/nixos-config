{ config, lib, pkgs, ... }:

{
  # Jellyfin, native (was the jellyfin/jellyfin OCI container). Going native
  # drops the nvidia-container-toolkit CDI dance: the service runs on the host
  # and links the driver directly, so there's no CDI generator to race at boot.
  #
  # On-disk state under /srv/appdata/Jellyfin (library DB, users, watch history,
  # plugins, metadata) carries over verbatim — dirs just map onto the native
  # module's split datadir/configdir/cachedir/logdir instead of the container's
  # single /config mount. encoding.xml is the exception: managed declaratively
  # below (forceEncodingConfig), since the transcode config was never hand-tuned
  # beyond selecting nvenc.
  services.jellyfin = {
    enable = true;
    # Opens TCP 8096/8920 + UDP 1900/7359 (WebUI, discovery, DLNA).
    openFirewall = true;

    dataDir   = "/srv/appdata/Jellyfin";
    configDir = "/srv/appdata/Jellyfin/config";
    logDir    = "/srv/appdata/Jellyfin/log";
    cacheDir  = "/srv/appdata/jellyfin-cache";

    # Transcode config, declaratively (forceEncodingConfig rewrites encoding.xml
    # from these options on every start, backing up the old one once).
    hardwareAcceleration = {
      enable = true;
      type = "nvenc";
      # nvenc only uses this for the module's non-null assertion + DeviceAllow;
      # actual GPU access is the /dev/nvidia* nodes opened in the systemd block.
      device = "/dev/dri/renderD128";
    };
    forceEncodingConfig = true;
    transcoding = {
      # NVENC encode (else nvenc is "selected" but video still encodes on CPU).
      enableHardwareEncoding = true;
      # NVDEC decode for the common source codecs (matches the prior config).
      # 10-bit HEVC/VP9 decode stay on via Jellyfin's own defaults, so they're
      # not listed. Note NVENC/NVDEC only engage when a client forces a real
      # VIDEO transcode — direct-play and remux (video stream copy) bypass the
      # GPU, which is correct.
      hardwareDecodingCodecs = {
        h264 = true;
        hevc = true;
        vc1 = true;
      };
      enableToneMapping = true;
    };
  };

  # Read the media library, still owned 99:100 (gid 100 = users) from the
  # LSIO/arr containers.
  users.users.jellyfin.extraGroups = [ "users" ];

  systemd.services.jellyfin = {
    # NB: no LD_LIBRARY_PATH for the driver libs — jellyfin-ffmpeg (via
    # ffmpeg-full) already bakes /run/opengl-driver/lib into libavcodec.so's
    # RUNPATH with addDriverRunpath, which is what dlopens libnvcuvid /
    # libnvidia-encode. If NVENC ever falls back to CPU with a libnvcuvid load
    # error in the journal, re-add: environment.LD_LIBRARY_PATH = "/run/opengl-driver/lib";

    # hardwareAcceleration.enable makes the module write DeviceAllow=[renderD128],
    # which flips this unit's cgroup device policy to closed — blocking the
    # /dev/nvidia* char nodes NVENC needs. Re-declare the full allow-list
    # (mkForce beats the module's mkIf). Node names verified on atilla; nvidia
    # nodes are 0666 so no group is needed, only the cgroup allow.
    serviceConfig.DeviceAllow = lib.mkForce [
      "/dev/dri/renderD128 rw"
      "/dev/nvidia0 rw"
      "/dev/nvidiactl rw"
      "/dev/nvidia-uvm rw"
      "/dev/nvidia-uvm-tools rw"
      "/dev/nvidia-modeset rw"
    ];

    # Recreate the container's mount points, but INSIDE this unit's private
    # mount namespace (BindPaths sets one up) — so /config and /data/* exist
    # only for jellyfin, never host-wide. This resolves the absolute paths
    # Jellyfin baked into its DB with no DB surgery / re-scan: metadata images
    # under /config, and media under /data (whose paths are hashed into item
    # IDs → watch state). /cache is intentionally NOT recreated — it's pure
    # cache and rebuilds itself on the native cacheDir.
    #
    # Media is bound read-only: jellyfin is a reader, the arr apps own writes.
    # If you turn on "save artwork/NFO with media" or trickplay-next-to-media,
    # move those entries to BindPaths (rw).
    serviceConfig.BindPaths = [ "/srv/appdata/Jellyfin:/config" ];
    serviceConfig.BindReadOnlyPaths = [
      "/srv/media/media/movies:/data/movies"
      "/srv/media/media/movies-fr:/data/movies-fr"
      "/srv/media/media/tv:/data/tvshows"
      "/srv/media/media/tv-fr:/data/tv-fr"
      "/srv/media/media/anime:/data/anime"
    ];

    unitConfig.RequiresMountsFor = lib.mkForce [
      "/srv/appdata/Jellyfin/config"
      "/srv/appdata/jellyfin-cache"
      "/srv/appdata/Jellyfin/log"
      "/srv/media"
    ];
  };
}
