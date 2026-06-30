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
}
