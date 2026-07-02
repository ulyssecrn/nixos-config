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
    #
    # Deliberately minimal for now: switch encoding to NVENC and nothing else.
    # Once the encode path is confirmed working, add hardware DECODE by listing
    # codecs under transcoding.hardwareDecodingCodecs (e.g. h264/hevc/vc1) —
    # left empty here means decode stays on CPU.
    hardwareAcceleration = {
      enable = true;
      type = "nvenc";
      # nvenc only uses this for the module's non-null assertion + DeviceAllow;
      # actual GPU access is the /dev/nvidia* nodes opened in the systemd block.
      device = "/dev/dri/renderD128";
    };
    forceEncodingConfig = true;
    # Without this, encoding.xml gets nvenc "selected" but hardware encoding off
    # (software encode) — this is what actually routes transcodes through NVENC.
    transcoding.enableHardwareEncoding = true;
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

    unitConfig.RequiresMountsFor = lib.mkForce [
      "/srv/appdata/Jellyfin/config"
      "/srv/appdata/jellyfin-cache"
      "/srv/appdata/Jellyfin/log"
      "/srv/media"
    ];
  };

  # The library was added in the container under /data/{movies,tvshows,...}, and
  # those paths are hashed into Jellyfin's item IDs (and thus watch state).
  systemd.tmpfiles.rules = [
    "d /srv/appdata/jellyfin-cache 0700 jellyfin jellyfin - -"
    "L+ /data/movies    - - - - /srv/media/media/movies"
    "L+ /data/movies-fr - - - - /srv/media/media/movies-fr"
    "L+ /data/tvshows   - - - - /srv/media/media/tv"
    "L+ /data/tv-fr     - - - - /srv/media/media/tv-fr"
    "L+ /data/anime     - - - - /srv/media/media/anime"
  ];
}
