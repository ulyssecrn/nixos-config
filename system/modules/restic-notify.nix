{ config, pkgs, ... }:

{
  # Shared restic state dir + Discord-webhook failure notifier. Imported by
  # any host running `services.restic.backups.*`. Each backup unit opts in
  # via `unitConfig.OnFailure = [ "restic-failure-notify@%n.service" ]`.
  #
  # /var/lib/restic/env must define DISCORD_WEBHOOK_URL plus the B2/S3
  # credentials used by the restic jobs themselves.

  # NixOS bakes restic into the systemd unit's PATH but not the user shell's
  # — add it here so interactive `restic snapshots`/restore works without a
  # nix-shell on any host that imports this.
  environment.systemPackages = [ pkgs.restic ];

  systemd.tmpfiles.rules = [
    "d /var/lib/restic       0700 root root - -"
    "d /var/lib/restic/dumps 0700 root root - -"
  ];

  systemd.services."restic-failure-notify@" = {
    description = "Discord notify on backup failure: %i";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/var/lib/restic/env";
    };
    scriptArgs = "%i";
    script = ''
      tail=$(${pkgs.systemd}/bin/journalctl -u "$1" --no-pager -n 20 -o cat 2>/dev/null || echo "(no journal)")
      ${pkgs.jq}/bin/jq -nc \
        --arg unit "$1" \
        --arg host "$(${pkgs.nettools}/bin/hostname)" \
        --arg tail "$tail" \
        '{content: ":rotating_light: **Backup failed**: \($unit) on \($host)\n```\n\($tail | .[0:1800])\n```"}' \
        | ${pkgs.curl}/bin/curl -fsS -X POST \
            -H "Content-Type: application/json" \
            --data-binary @- \
            "$DISCORD_WEBHOOK_URL" || true
    '';
  };
}
