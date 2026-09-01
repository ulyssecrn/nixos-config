{ config, lib, pkgs, ... }:

let
  tsnet = "shad-powan.ts.net";

  # Grafana's upstream default is 3000, which tracearr already owns on this
  # host (see caddy.nix).
  grafanaPort = 3030;

  exporterPorts = {
    node = 9100;
    smartctl = 9633;
    zfs = 9134;
    "nvidia-gpu" = 9835;
    rasdaemon = 10029;
  };

  # Scrape map. `addr` is loopback for atilla itself and the MagicDNS name for
  # everything else: system/modules/metrics.nix opens the exporter ports on
  # tailscale0 only, so arriving over the tailnet is what makes the firewall
  # rule match — and it's the only address that keeps working when loki is off
  # the LAN. Tailscale still takes the direct LAN path for genghis/hannibal, so
  # this costs nothing at home.
  #
  # `role` separates always-on servers from laptops: only servers get paged on
  # up == 0, because a closed lid is not an incident.
  #
  # odin is deliberately absent. The machine is gone; its config still picks up
  # the node exporter from base.nix so the host keeps evaluating, but scraping
  # it would just pin a target at up == 0 forever.
  fleet = {
    atilla = {
      addr = "localhost";
      role = "server";
      exporters = [ "node" "smartctl" "zfs" "nvidia-gpu" "rasdaemon" ];
    };
    genghis = {
      addr = "genghis.${tsnet}";
      role = "server";
      exporters = [ "node" "smartctl" "nvidia-gpu" "rasdaemon" ];
    };
    hannibal = {
      addr = "hannibal.${tsnet}";
      role = "server";
      # No smartctl — the root device is an SD card, which has no SMART. No
      # rasdaemon exporter either: it's a Python package, and a Pi 5 has no
      # machine-check banks to report on.
      exporters = [ "node" ];
    };
    loki = {
      addr = "loki.${tsnet}";
      role = "laptop";
      exporters = [ "node" "smartctl" ];
    };
  };

  # One job per exporter, one target per host that runs it. `instance` is
  # relabelled to the bare hostname so a dashboard legend reads "genghis", not
  # "genghis.shad-powan.ts.net:9100", and so it stays stable if an address
  # ever changes.
  fleetScrapeConfigs = lib.mapAttrsToList (exporter: port: {
    job_name = exporter;
    static_configs = lib.mapAttrsToList (host: h: {
      targets = [ "${h.addr}:${toString port}" ];
      labels = { instance = host; role = h.role; };
    }) (lib.filterAttrs (_: h: lib.elem exporter h.exporters) fleet);
  }) exporterPorts;

  alertRules = {
    groups = [
      {
        name = "fleet";
        rules = [
          {
            alert = "InstanceDown";
            expr = ''up{role="server"} == 0'';
            for = "10m";
            labels.severity = "critical";
            annotations.summary =
              "{{ $labels.instance }}: {{ $labels.job }} exporter unreachable for 10m";
          }
          {
            # Pseudo-filesystems and the podman/nix overlay mounts would
            # otherwise dominate this alert.
            alert = "FilesystemFillingUp";
            expr = ''
              100 * node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay|squashfs|autofs|fuse.*"}
                / node_filesystem_size_bytes < 10
            '';
            for = "1h";
            labels.severity = "warning";
            annotations.summary =
              "{{ $labels.instance }}: {{ $labels.mountpoint }} below 10% free";
          }
          {
            alert = "FilesystemCritical";
            expr = ''
              100 * node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay|squashfs|autofs|fuse.*"}
                / node_filesystem_size_bytes < 5
            '';
            for = "15m";
            labels.severity = "critical";
            annotations.summary =
              "{{ $labels.instance }}: {{ $labels.mountpoint }} below 5% free";
          }
          {
            alert = "SystemdUnitFailed";
            expr = ''node_systemd_unit_state{state="failed"} == 1'';
            for = "15m";
            labels.severity = "warning";
            annotations.summary =
              "{{ $labels.instance }}: systemd unit {{ $labels.name }} is failed";
          }
          {
            alert = "MemoryPressure";
            expr = ''
              100 * node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 10
            '';
            for = "30m";
            labels.severity = "warning";
            annotations.summary =
              "{{ $labels.instance }}: under 10% memory available for 30m";
          }
          {
            # No `for` — an OOM kill is a point event, not a state.
            alert = "OOMKill";
            expr = "increase(node_vmstat_oom_kill[1h]) > 0";
            labels.severity = "warning";
            annotations.summary =
              "{{ $labels.instance }}: the kernel OOM-killed a process in the last hour";
          }
          {
            # Catches a broken textfile writer, which would otherwise fail
            # silently and look like "the metric just isn't there".
            alert = "TextfileCollectorError";
            expr = "node_textfile_scrape_error == 1";
            for = "30m";
            labels.severity = "warning";
            annotations.summary =
              "{{ $labels.instance }}: node_exporter can't parse a textfile metric drop";
          }
          {
            alert = "SmartFailure";
            expr = "smartctl_device_smart_status == 0";
            for = "15m";
            labels.severity = "critical";
            annotations.summary =
              "{{ $labels.instance }}: SMART overall-health FAILED on {{ $labels.device }}";
          }
        ];
      }
    ];
  };

  # `\$` keeps the literal ${...} — Grafana's import placeholder, not a Nix
  # interpolation. Same class of trap as the YAML one in AGENTS.md.
  dsPlaceholder = "\${DS_PROMETHEUS}";

  # Upstream dashboards, pinned by revision. Fetched rather than vendored:
  # 1860 alone is half a megabyte of generated JSON.
  nodeExporterFull = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/1860/revisions/41/download";
    hash = "sha256-EywgxEayjwNIGDvSmA/S56Ld49qrTSbIYFpeEXBJlTs=";
  };
  smartctlDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/22604/revisions/3/download";
    hash = "sha256-gpm/4rzcNv6br8L8cs9O6iWEScojfImWUi1uRXW8UpM=";
  };
  nvidiaDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/14574/revisions/15/download";
    hash = "sha256-L1yXeL3LLnyPHlS0l30075gO+WS/WE3zXD8eNeR1r80=";
  };

  # 1860 and 22604 ship as UI *exports*: their datasource is a ${DS_PROMETHEUS}
  # input that the import wizard normally prompts for, and a provisioned file
  # never gets that prompt — every panel renders "datasource not found" until
  # the placeholder is swapped for our datasource's uid. 14574 instead uses a
  # datasource *template variable*, which resolves on its own, so it's copied
  # as-is.
  dashboards = pkgs.runCommand "grafana-fleet-dashboards" { } ''
    mkdir -p $out
    substitute ${nodeExporterFull} $out/node-exporter-full.json \
      --replace-fail '${dsPlaceholder}' 'prometheus'
    substitute ${smartctlDashboard} $out/smartctl.json \
      --replace-fail '${dsPlaceholder}' 'prometheus'
    cp ${nvidiaDashboard} $out/nvidia-gpu.json
  '';
in
{
  # ── atilla's own exporters ──────────────────────────────────────────
  # node + the firewall rule come from system/modules/metrics.nix; these are
  # the ones that only make sense on this host.
  services.prometheus.exporters = {
    # Autodiscovers devices when `devices` is empty. The module creates the
    # smartctl-exporter-access group and the udev rule that ACLs /dev/nvme*.
    smartctl.enable = true;

    zfs.enable = true;  # all pools; feeds dashboards, ZED still owns fault alerting

    # Pascal 1080 Ti — the exporter shells out to nvidia-smi from
    # hardware.nvidia.package.
    "nvidia-gpu".enable = true;

    # rasdaemon is already enabled fleet-wide (base.nix, record = true); this
    # turns its event DB into metrics. Enabled on the two x86 boxes only, so a
    # repeat of genghis' 2026-06-16 uncorrected machine-check shows up as a
    # counter with a timestamp instead of a journal line nobody re-reads.
    rasdaemon.enable = true;
  };

  # ── Prometheus ──────────────────────────────────────────────────────
  # Loopback-only; reached through Caddy at prometheus.corne.sh. 90d of ~5k
  # series at 30s is a few GB on the LUKS root — well within budget, and the
  # expression browser is what makes an alert debuggable.
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    retentionTime = "90d";
    webExternalUrl = "http://prometheus.corne.sh/";

    globalConfig = {
      scrape_interval = "30s";
      evaluation_interval = "30s";
    };

    scrapeConfigs = fleetScrapeConfigs ++ [
      {
        job_name = "prometheus";
        static_configs = [{
          targets = [ "127.0.0.1:9090" ];
          labels = { instance = "atilla"; role = "server"; };
        }];
      }
    ];

    # `rules` takes rule-file *contents*; JSON is valid YAML, so this stays a
    # normal Nix attrset instead of a here-doc.
    rules = [ (builtins.toJSON alertRules) ];

    alertmanagers = [
      { static_configs = [{ targets = [ "127.0.0.1:9093" ]; }]; }
    ];
  };

  # ── Alertmanager ────────────────────────────────────────────────────
  # Loopback-only: it has no auth and its whole job is firing the webhook.
  # Silences are set from Grafana's alerting view or over an SSH tunnel.
  #
  # The webhook URL is interpolated by envsubst at unit start, so it never
  # enters the store. Reuse the same Discord webhook as restic-notify /
  # flake-bot — the PLAIN url, not the /slack variant zed.nix needs. The env
  # file lives outside StateDirectory=alertmanager so systemd's DynamicUser
  # ownership never touches it:
  #   sudo install -d -m 0700 /var/lib/alertmanager-secrets
  #   echo 'DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/XXX/YYY' \
  #     | sudo tee /var/lib/alertmanager-secrets/env > /dev/null
  #   sudo chmod 0600 /var/lib/alertmanager-secrets/env
  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9093;
    environmentFile = "/var/lib/alertmanager-secrets/env";
    # amtool runs inside the Nix sandbox and can't see the env file, so it
    # would reject the unsubstituted "$DISCORD_WEBHOOK_URL" as a malformed URL.
    checkConfig = false;
    configuration = {
      route = {
        receiver = "discord";
        group_by = [ "alertname" "instance" ];
        group_wait = "1m";
        group_interval = "5m";
        # A still-firing alert re-posts twice a day. Anything shorter turns
        # a slowly-filling disk into a channel full of duplicates.
        repeat_interval = "12h";
      };
      receivers = [{
        name = "discord";
        discord_configs = [{
          webhook_url = "$DISCORD_WEBHOOK_URL";
          send_resolved = true;
        }];
      }];
    };
  };

  # ── Grafana ─────────────────────────────────────────────────────────
  # Datasource and dashboards are provisioned from Nix, so the sqlite DB only
  # ever holds users, preferences and anything hand-built in the UI.
  #
  # Two secrets, handed to the unit by systemd LoadCredential and read back
  # through Grafana's $__file provider, so neither enters the store. Same
  # shape as paperless.nix: the files stay root:root 0400 and systemd (as
  # root) does the reading, which is what lets them be created *before* the
  # first `nrs` — a grafana-owned file couldn't be, since the grafana user
  # doesn't exist until activation. LoadCredential exposes them under
  # /run/credentials/grafana.service/ on a tmpfs, readable only by the unit.
  #
  #   sudo install -d -m700 /var/lib/grafana-secrets
  #   printf '%s' '<password>' \
  #     | sudo tee /var/lib/grafana-secrets/admin-password >/dev/null
  #   head -c 32 /dev/urandom | base64 | tr -d '\n' \
  #     | sudo tee /var/lib/grafana-secrets/secret-key >/dev/null
  #   sudo chmod 400 /var/lib/grafana-secrets/{admin-password,secret-key}
  #
  # admin_password only applies when Grafana first creates the admin user —
  # change it in the UI afterwards, not here.
  #
  # secret_key encrypts datasource credentials in the sqlite DB. It lost its
  # upstream default in 26.05 and is now a hard assertion. Treat it as
  # write-once: there is no supported rotation, and changing it makes every
  # already-encrypted secret in grafana.db unreadable. It is also the one
  # thing in the restic snapshot of /var/lib/grafana that the DB can't be
  # decrypted without.
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = grafanaPort;
        # Without these two, every Grafana-generated redirect and share link
        # points back at localhost:3030 instead of the proxied hostname.
        domain = "grafana.corne.sh";
        root_url = "http://grafana.corne.sh/";
      };
      analytics.reporting_enabled = false;
      users.allow_sign_up = false;
      security = {
        admin_user = "ucorne";
        admin_password = "$__file{/run/credentials/grafana.service/admin-password}";
        secret_key = "$__file{/run/credentials/grafana.service/secret-key}";
      };
    };

    provision = {
      enable = true;

      datasources.settings = {
        apiVersion = 1;
        datasources = [{
          name = "Prometheus";
          type = "prometheus";
          # Fixed uid — this is what the dashboard placeholder gets rewritten
          # to above, so it must not drift.
          uid = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:9090";
          isDefault = true;
        }];
      };

      dashboards.settings = {
        apiVersion = 1;
        providers = [{
          name = "fleet";
          type = "file";
          folder = "Fleet";
          options.path = dashboards;
          # The files are read-only store paths; letting the UI think it can
          # save over them just produces confusing errors.
          disableDeletion = true;
          allowUiUpdates = false;
        }];
      };
    };
  };

  systemd.services.grafana.serviceConfig.LoadCredential = [
    "admin-password:/var/lib/grafana-secrets/admin-password"
    "secret-key:/var/lib/grafana-secrets/secret-key"
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/alertmanager-secrets 0700 root root - -"
    "d /var/lib/grafana-secrets      0700 root root - -"
  ];
}
