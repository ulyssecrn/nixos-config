{ config, pkgs, lib, ... }:

{
  # ── Pi-hole FTL (DNS resolver + blocking engine) ────────────────────
  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    openFirewallWebserver = true;
    queryLogDeleter.enable = true;
    lists = [
      {
        url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt";
        type = "block";
        enabled = true;
        description = "hagezi Pro";
      }
      {
        url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt";
        type = "block";
        enabled = true;
        description = "hagezi Threat Intelligence Feeds";
      }
    ];
    settings = {
      dns = {
        # Forward to local dnscrypt-proxy2 (DoH to Quad9 + Mullvad).
        upstreams = [ "127.0.0.1#5053" ];
        # Respond to queries from any source IP (default "LOCAL" drops
        # anything outside the LAN subnet with "ignoring query from
        # non-local network …"). Tailscale clients hit pihole from the
        # 100.64.0.0/10 CGNAT range, which the default treats as remote.
        listeningMode = "ALL";
      };
      # Pi-hole bundles its own NTP — the LAN already has time, skip it.
      ntp = {
        ipv4.active = false;
        ipv6.active = false;
        sync.active = false;
      };
      webserver.domain = lib.mkForce "10.10.10.11,pihole.corne.sh";
    };
  };

  # ── Pi-hole Web (admin UI) ──────────────────────────────────────────
  services.pihole-web = {
    enable = true;
    ports = [ 80 ];
  };

  # ── systemd-resolved coexistence ────────────────────────────────────
  # Release the stub listener so pihole-ftl can bind port 53 on all
  # interfaces. resolved still runs for tailscale's DNS integration.
  services.resolved.settings.Resolve.DNSStubListener = false;

  # Silence a benign FTL.log warning about a missing versions file.
  systemd.tmpfiles.rules = [
    "f /etc/pihole/versions 0644 pihole pihole - -"
  ];
}
