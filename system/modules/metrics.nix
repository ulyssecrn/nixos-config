{ config, lib, ... }:

let
  # Every exporter name used anywhere in the fleet. Deliberately an explicit
  # list rather than iterating `config.services.prometheus.exporters`: that
  # attrset also carries stubs for *removed* options (minio, …) which throw
  # the moment anything forces them. Add a name here when a host starts using
  # a new exporter.
  fleetExporters = [ "node" "smartctl" "zfs" "nvidia-gpu" "rasdaemon" ];
in
{
  # Fleet-wide metrics endpoint. Imported from system/profiles/base.nix, so
  # every host exports; atilla is the only scraper (see
  # hosts/atilla/services/monitoring.nix). Host-specific exporters (smartctl,
  # zfs, nvidia-gpu, rasdaemon) are enabled in each host's configuration.nix —
  # only what is genuinely universal lives here, plus the one firewall rule
  # that covers all of them.
  #
  # Exposure: exporters bind 0.0.0.0, but their ports are opened *only* on
  # tailscale0. That makes scraping identical whether the target is a LAN
  # server or loki on a café wifi, and leaves nothing listening to the LAN or
  # the WAN. atilla scrapes its own exporters over loopback, which the
  # firewall never sees.

  services.prometheus.exporters.node = {
    enable = true;
    # On top of node_exporter's defaults. `systemd` is what the unit-failure
    # alert keys on, `processes` gives per-process RSS (the llama.cpp / immich
    # "what ate the RAM" question), `textfile` is a drop box for jobs that
    # want to publish their own metrics.
    enabledCollectors = [ "systemd" "processes" "textfile" ];
    extraFlags = [ "--collector.textfile.directory=/var/lib/node-exporter-textfile" ];
  };

  # Root-owned: the writers are systemd jobs, node_exporter only reads.
  systemd.tmpfiles.rules = [
    "d /var/lib/node-exporter-textfile 0755 root root - -"
  ];

  # Derived from whatever exporters the host actually enabled, so adding e.g.
  # smartctl to a host doesn't also need a firewall line next to it. The
  # module's own `openFirewall` is deliberately unused — it opens the port on
  # every interface.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts =
    map (n: config.services.prometheus.exporters.${n}.port)
      (lib.filter (n: config.services.prometheus.exporters.${n}.enable) fleetExporters);
}
