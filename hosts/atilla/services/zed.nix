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
}
