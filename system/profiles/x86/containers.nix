{ config, lib, pkgs, ... }:

{
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.oci-containers.backend = "podman";

  environment.systemPackages = with pkgs; [
    podman-compose
  ];

  # Weekly auto-update, opt-in per container via the label
  # `io.containers.autoupdate = "registry"`. `podman auto-update` compares the
  # pinned tag's local digest against the registry and restarts (rolling back on
  # a failed start/healthcheck) only the ones that moved. NixOS ships no enable
  # option for this, so the units are defined here. No-op on hosts with no
  # labeled containers (e.g. genghis). Stateful apps deliberately opt OUT —
  # immich (breaking cross-release DB migrations) and nextcloud + its mariadb
  # (no major-version skips) get updated by hand, with a backup.
  systemd.services.podman-auto-update = {
    description = "Auto-update opted-in podman containers";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.virtualisation.podman.package}/bin/podman auto-update";
      ExecStartPost = "${config.virtualisation.podman.package}/bin/podman image prune -f";
    };
  };
  systemd.timers.podman-auto-update = {
    description = "Weekly podman auto-update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 04:00:00";
      Persistent = true;
      RandomizedDelaySec = "45m";
    };
  };
}
