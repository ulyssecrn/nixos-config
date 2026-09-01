{ config, pkgs, ... }:

{
  # Serves genghis's store (built weekly by flake-bot) so other hosts pull
  # prebuilt closures like loki's patched kernel instead of rebuilding.
  #
  # Bootstrap once on genghis, then paste cache-pub-key.pem into base.nix.
  # nix-serve runs as a DynamicUser and loads the key via systemd
  # LoadCredential, so the key is just a root-owned file (no nix-serve user):
  #   sudo mkdir -p /var/lib/nix-serve
  #   sudo nix-store --generate-binary-cache-key genghis-cache-1 \
  #     /var/lib/nix-serve/cache-priv-key.pem /var/lib/nix-serve/cache-pub-key.pem
  #   sudo systemctl restart nix-serve
  #
  # nix-serve-ng (Haskell) rather than the Perl original: the latter serves NARs
  # single-threaded and wedges under the parallel requests a fleet rebuild makes
  # — it keeps accepting connections and never answers, and the client sits
  # there until stalled-download-timeout. Drop-in, same options.
  services.nix-serve = {
    enable = true;
    package = pkgs.nix-serve-ng;
    secretKeyFile = "/var/lib/nix-serve/cache-priv-key.pem";
  };

  # LAN-only (no WAN forward); source-restriction would need nftables, fleet is on iptables.
  networking.firewall.allowedTCPPorts = [ 5000 ];
}
