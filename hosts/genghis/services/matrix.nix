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

      # Remove these two once @ulysse + @hermes exist, before exposing via Pangolin.
      allow_registration = true;
      yes_i_am_very_very_sure_i_want_an_open_registration_server_prone_to_abuse = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 6167 ];
}
