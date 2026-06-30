{ lib, pkgs, ... }:

{
  # Kernel WireGuard tunnel to Pangolin's Gerbil server (ch-vps), used as the
  # data path for high-bandwidth resources (Jellyfin). newt's userspace proxy
  # caps throughput at ~7-10 Mbps; kernel WG removes that ceiling. newt stays
  # for the low-bandwidth resources.
  #
  # Pangolin generated the keypair; keep its private key OUT of the store:
  #   sudo install -d -m700 /var/lib/wireguard
  #   printf %s '<PrivateKey from Pangolin>' | sudo tee /var/lib/wireguard/pangolin.key
  #   sudo chmod 600 /var/lib/wireguard/pangolin.key
  #
  # Then point the Jellyfin resource's upstream at http://100.89.128.8:8096 (http).

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
