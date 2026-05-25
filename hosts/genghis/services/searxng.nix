{ config, lib, pkgs, ... }:

{
  # SearXNG — privacy-respecting metasearch aggregator. Used by open-webui's
  # web-search feature; not exposed to LAN (binds to 127.0.0.1).
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
      use_default_settings = true;
      server = {
        port = 8888;
        bind_address = "127.0.0.1";
        secret_key = "$SEARXNG_SECRET_KEY";  # substituted from environmentFile at activation
      };
      # JSON output is required by open-webui's SearXNG integration.
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
}
