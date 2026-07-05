{ lib, pkgs, ... }:

{
  # Kernel WireGuard tunnel to Pangolin's Gerbil (ch-vps) — the public data path
  # for atilla's Pangolin resources (Jellyfin, Nextcloud), replacing the newt
  # connector. newt's userspace proxy caps throughput at ~7 Mbps; kernel WG hit
  # ~270 Mbps in the same test. Root cause / why we don't just use newt:
  #   https://github.com/orgs/fosrl/discussions/512
  #
  # Pangolin generated the keypair; keep its private key OUT of the store:
  #   sudo install -d -m700 /var/lib/wireguard
  #   printf %s '<PrivateKey from Pangolin>' | sudo tee /var/lib/wireguard/pangolin.key
  #   sudo chmod 600 /var/lib/wireguard/pangolin.key
  #
  # Each Pangolin resource lives on the WireGuard site and targets
  # http://100.89.128.8:<svc-port> (http).

  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkDefault true;

  networking.wireguard.interfaces.pangolin = {
    ips = [ "100.89.128.8/30" ];
    listenPort = 51820;
    mtu = 1280;                         # avoid PMTU blackholes through the tunnel
    privateKeyFile = "/var/lib/wireguard/pangolin.key";

    # Clamp TCP MSS to the path MTU so large transfers don't stall mid-stream.
    postSetup = ''
      ${pkgs.iptables}/bin/iptables -t mangle -A FORWARD -i pangolin -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
      ${pkgs.iptables}/bin/iptables -t mangle -A FORWARD -o pangolin -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    '';
    postShutdown = ''
      ${pkgs.iptables}/bin/iptables -t mangle -D FORWARD -i pangolin -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
      ${pkgs.iptables}/bin/iptables -t mangle -D FORWARD -o pangolin -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    '';

    peers = [{
      publicKey = "R0PL22iveKqoCO4u9s2GZbG2p/tH8CrCNFXW2J+yPX4=";
      endpoint = "pangolin.corne.sh:51820";
      allowedIPs = [ "100.89.128.1/32" ];
      persistentKeepalive = 5;
    }];
  };

  # Pangolin's WG subnet (100.89.128.0/24) lives INSIDE Tailscale's CGNAT range
  # 100.64.0.0/10. Tailscale plants an anti-spoof rule in its own ts-input chain
  #   -A ts-input -s 100.64.0.0/10 ! -i tailscale0 -j DROP
  # and ts-input runs in INPUT *before* nixos-fw — so every packet Pangolin
  # delivers here (src/dst both 100.89.x, arriving on `pangolin`, not tailscale0)
  # is dropped before the firewall's port-accepts are ever reached. Native host
  # services (jellyfin on 8096) were unreachable via Pangolin as a result;
  # containers dodged it because their published ports are DNAT'd onto FORWARD,
  # which ts-input (INPUT-only) never sees.
  #
  # Trust the pangolin tunnel interface at the head of INPUT, ahead of ts-input
  # (only the Gerbil peer can inject packets here, same trust as tailscale0).
  #
  # This MUST run after tailscaled: on boot, tailscaled plants `-I INPUT 1 -j
  # ts-input` at the head of INPUT. If we insert earlier (e.g. via
  # firewall.extraCommands, which runs before tailscaled starts), tailscaled's
  # insert lands ABOVE ours and the 100.64.0.0/10 drop eats Pangolin traffic
  # again — which is exactly what a reboot / flake-update reboot reproduced.
  # A oneshot ordered `after` tailscaled makes our -I land on top last;
  # partOf+wantedBy re-applies it whenever tailscaled restarts (e.g. its config
  # changes on a rebuild). Idempotent: delete-then-insert.
  systemd.services.pangolin-fw-trust = {
    description = "Trust pangolin WG iface ahead of Tailscale's ts-input drop";
    after = [ "tailscaled.service" "firewall.service" ];
    partOf = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" "tailscaled.service" ];
    path = [ pkgs.iptables ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      iptables -D INPUT -i pangolin -j ACCEPT 2>/dev/null || true
      iptables -I INPUT -i pangolin -j ACCEPT
    '';
  };
}
