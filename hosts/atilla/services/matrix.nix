{ ... }:

{
  # Conduit Matrix homeserver — backend for Hermes' Matrix access + Element.
  # Single-user, non-federating. Public via Pangolin, which reaches it over the
  # WireGuard site at http://10.253.0.4:6167 (like Nextcloud); Hermes on genghis
  # reaches it over the LAN at http://10.10.10.10:6167.
  services.matrix-conduit = {
    enable = true;
    settings.global = {
      server_name = "matrix.corne.sh";
      address = "0.0.0.0"; # module default ::1 is loopback-only; the WG site + LAN need it
      port = 6167;
      database_backend = "rocksdb";
      allow_federation = false;

      allow_registration = false;
    };
  };

  networking.firewall.allowedTCPPorts = [ 6167 ];
}
