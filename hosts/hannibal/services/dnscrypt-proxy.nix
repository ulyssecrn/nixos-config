{ config, pkgs, ... }:

{
  # Local DoH proxy. Pi-hole forwards to 127.0.0.1#5053; dnscrypt-proxy2
  # speaks DoH upstream to Quad9 + Mullvad
  services.dnscrypt-proxy2 = {
    enable = true;
    settings = {
      listen_addresses = [ "127.0.0.1:5053" ];

      server_names = [
        "quad9-doh-ip4-port443-nofilter-pri"
        "mullvad-doh"
      ];

      # Refuse any resolver that doesn't meet these
      require_dnssec = true;
      require_nolog = true;
      require_nofilter = true;

      # Plain-DNS bootstrap for fetching the resolver list and DoH endpoints
      # on first start.
      bootstrap_resolvers = [ "1.1.1.1:53" "9.9.9.9:53" ];

      sources.public-resolvers = {
        urls = [
          "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
        ];
        minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
        refresh_delay = 73; # hours
      };
    };
  };
}
