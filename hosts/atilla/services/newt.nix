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

  # `native` makes newt create a real `newt` TUN interface (so traffic rides the
  # kernel TCP stack with proper window scaling, instead of the userspace
  # netstack that throttled us to ~7 Mbps). The upstream userspace-oriented
  # sandbox blocks it three ways: PrivateDevices hides /dev/net/tun,
  # PrivateUsers confines CAP_NET_ADMIN to a private userns, and it grants no
  # ambient caps at all.
  boot.kernelModules = [ "tun" ];
  systemd.services.newt.serviceConfig = {
    AmbientCapabilities = [ "CAP_NET_ADMIN" ];
    PrivateUsers = lib.mkForce false;
    PrivateDevices = lib.mkForce false;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/newt 0700 root root - -"
  ];
}
