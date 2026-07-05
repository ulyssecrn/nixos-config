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
  # http://10.253.0.4:<svc-port> (http).
  #
  # The Gerbil tunnel pool is deliberately 10.253.0.0/20 (set via
  # `gerbil.subnet_group` in Pangolin's config.yml). Its default is 100.89.x,
  # which sits inside Tailscale's CGNAT range 100.64.0.0/10 — Tailscale's
  # ts-input chain drops `-s 100.64.0.0/10 ! -i tailscale0` in INPUT before the
  # host firewall, so Pangolin traffic to native host services was silently
  # eaten (containers dodged it via the DNAT/FORWARD path). Moving Gerbil off
  # 100.64/10 is the clean fix; do NOT let this drift back into 100.89.x.

  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkDefault true;

  networking.wireguard.interfaces.pangolin = {
    ips = [ "10.253.0.4/30" ];
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
      allowedIPs = [ "10.253.0.1/32" ];
      persistentKeepalive = 5;
    }];
  };
}
