{ config, ... }:

{
  # Serves genghis's store (built weekly by flake-bot) so other hosts pull
  # prebuilt closures like loki's patched kernel instead of rebuilding.
  #
  # Bootstrap once on genghis, then paste cache-pub-key.pem into base.nix:
  #   sudo install -d -o nix-serve -g nix-serve -m 0750 /var/lib/nix-serve
  #   sudo -u nix-serve nix-store --generate-binary-cache-key genghis-cache-1 \
  #     /var/lib/nix-serve/cache-priv-key.pem /var/lib/nix-serve/cache-pub-key.pem
  services.nix-serve = {
    enable = true;
    secretKeyFile = "/var/lib/nix-serve/cache-priv-key.pem";
  };

  # LAN-only (no WAN forward); source-restriction would need nftables, fleet is on iptables.
  networking.firewall.allowedTCPPorts = [ 5000 ];
}
