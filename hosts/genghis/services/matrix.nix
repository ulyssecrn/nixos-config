{ ... }:

{
  # Conduit Matrix homeserver — backend for Hermes' Matrix access + Element.
  # Single-user, non-federating; public via Pangolin (which terminates TLS).
  services.matrix-conduit = {
    enable = true;
    settings.global = {
      server_name = "matrix.corne.sh";
      address = "0.0.0.0"; # module default ::1 is loopback-only; Pangolin's newt needs the LAN
      port = 6167;
      database_backend = "rocksdb";
      allow_federation = false;
      allow_registration = false;
    };
  };

  networking.firewall.allowedTCPPorts = [ 6167 ];
}
