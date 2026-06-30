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
      endpoint = "https://pangolin.corne.sh";
      # Kernel WireGuard, not the default userspace netstack: the netstack's
      # unscaled TCP window caps a single stream to ~7-10 Mbps over the VPS's
      # 16ms RTT (measured), which throttled Jellyfin. Kernel WG uses the host
      # TCP stack and isn't window-bound.
      native = true;
    };
  };

  # `native` creates a kernel WireGuard interface, which the upstream module's
  # userspace-oriented sandbox forbids. Preload the module and grant just
  # CAP_NET_ADMIN in the host netns (no private userns).
  boot.kernelModules = [ "wireguard" ];
  systemd.services.newt.serviceConfig = {
    AmbientCapabilities = [ "CAP_NET_ADMIN" ];
    PrivateUsers = lib.mkForce false;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/newt 0700 root root - -"
  ];
}
