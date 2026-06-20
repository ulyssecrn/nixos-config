{ config, pkgs, ... }:

{
  # ZFS Event Daemon — fault/scrub/resilver notifications to Discord via the
  # Slack-compatible webhook endpoint (append /slack to a Discord webhook URL
  # and zed's bundled slack-notify zedlet works as-is).
  #
  # The webhook URL lives outside the repo at /var/lib/zfs-zed/discord-webhook
  # (root-only, single line, no trailing newline matters but ok). zed.rc is
  # sourced as bash, so `$(cat …)` runs at zedlet startup and the URL never
  # touches the Nix store. Create the file once:
  #   sudo install -d -m 0700 /var/lib/zfs-zed
  #   echo -n 'https://discord.com/api/webhooks/XXX/YYY/slack' \
  #     | sudo tee /var/lib/zfs-zed/discord-webhook > /dev/null
  #   sudo chmod 0600 /var/lib/zfs-zed/discord-webhook
  systemd.tmpfiles.rules = [
    "d /var/lib/zfs-zed 0700 root root -"
  ];

  services.zfs.zed = {
    enableMail = false;
    settings = {
      ZED_DEBUG_LOG = "/var/log/zed.log";
      ZED_NOTIFY_INTERVAL_SECS = 3600;
      ZED_NOTIFY_VERBOSE = true;

      ZED_SLACK_WEBHOOK_URL = "$(cat /var/lib/zfs-zed/discord-webhook)";

      ZED_SCRUB_AFTER_RESILVER = true;
    };
  };

  # ZED only notifies; nothing was actually running scrubs. Monthly scrub so
  # latent bit-rot is detected/repaired (and ZED reports the result). Default
  # is weekly — too heavy for an HDD mirror, so pin it to monthly.
  services.zfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  # Uptime Kuma heartbeat — the silence-detection complement to ZED's
  # fault-event Discord pings. ZED is blind to (a) capacity (it never warns as
  # a pool fills) and (b) zed itself dying; this asserts every pool ONLINE and
  # under threshold, pushing only when healthy. Push URL (systemd EnvironmentFile,
  # so the & in the query string needs NO quoting) in /var/lib/zfs-zed/kuma.env:
  #   KUMA_URL=http://kuma.corne.sh/api/push/XXXX?status=up&msg=OK&ping=
  systemd.services.zfs-heartbeat = {
    description = "Uptime Kuma heartbeat: ZFS pool health + capacity";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/var/lib/zfs-zed/kuma.env";
    };
    path = [ pkgs.zfs pkgs.curl pkgs.gnugrep pkgs.coreutils ];
    script = ''
      set -euo pipefail

      # Covers DEGRADED/FAULTED and known data errors in one shot.
      if ! zpool status -x | grep -q "all pools are healthy"; then
        echo "ZFS unhealthy:"; zpool status -x
        exit 1
      fi

      # zpool status -x does NOT flag a near-full pool — check capacity too.
      threshold=90
      fail=0
      while read -r name cap; do
        cap=''${cap%\%}
        if [ "$cap" -ge "$threshold" ]; then
          echo "pool $name at ''${cap}% (>= ''${threshold}%)"
          fail=1
        fi
      done < <(zpool list -H -o name,capacity)
      [ "$fail" -eq 0 ] || exit 1

      curl -fsS --max-time 10 "$KUMA_URL" >/dev/null || true
    '';
  };

  systemd.timers.zfs-heartbeat = {
    description = "Probe + push ZFS health every 5 min";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
      AccuracySec = "1s";
      Unit = "zfs-heartbeat.service";
    };
  };
}
