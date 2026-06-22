{ config, lib, pkgs, ... }:

{
  # Newt — Pangolin site connector.
  #
  # Sensitive credentials live outside the nix store at:
  #   /var/lib/newt/env   (root:root mode 0600)
  # File contents:
  #   NEWT_ID=<id from pangolin dashboard>
  #   NEWT_SECRET=<secret from pangolin dashboard>

  services.newt = {
    enable = true;
    environmentFile = "/var/lib/newt/env";
    settings = {
      endpoint = "pangolin.corne.sh";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/newt 0700 root root - -"
  ];
}
