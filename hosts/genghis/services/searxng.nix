{ config, lib, pkgs, ... }:

{
  # SearXNG — privacy-respecting metasearch aggregator. Used by LibreChat's
  # web-search provider; not exposed to LAN (binds to 127.0.0.1).
  #
  # The secret_key is loaded from environmentFile so it stays out of the Nix
  # store. Create the file once:
  #   sudo install -d -m 0700 -o searx -g searx /var/lib/searxng
  #   echo "SEARXNG_SECRET_KEY=$(openssl rand -hex 32)" \
  #     | sudo tee /var/lib/searxng/env > /dev/null
  #   sudo chmod 0600 /var/lib/searxng/env
  #   sudo chown searx:searx /var/lib/searxng/env
  services.searx = {
    enable = true;
    package = pkgs.searxng;
    environmentFile = "/var/lib/searxng/env";
    settings = {
      # Inherit upstream defaults but drop engines that need DB tables we
      # don't initialize (radio browser logs a noisy sqlite error otherwise).
      use_default_settings = {
        engines.remove = [ "radio browser" ];
      };
      server = {
        port = 8888;
        # 0.0.0.0 so the LibreChat container can reach us via the podman
        # bridge gateway (host.containers.internal). Port 8888 is NOT in
        # networking.firewall.allowedTCPPorts, so LAN access is still blocked
        # — only the loopback + podman bridge can hit it.
        bind_address = "0.0.0.0";
        secret_key = "$SEARXNG_SECRET_KEY";
      };
      # JSON output is required by LibreChat's SearXNG integration.
      search = {
        formats = [ "html" "json" ];
        safe_search = 0;
      };
      ui = {
        infinite_scroll = true;
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/searxng 0700 searx searx - -"
  ];

  # Containers on genghis reach host services via the podman bridge gateway.
  # Mark the interface trusted so the firewall stops dropping inbound on
  # ports we deliberately don't expose to the LAN.
  networking.firewall.trustedInterfaces = [ "podman0" ];
}
