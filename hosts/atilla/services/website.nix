{ ... }:

{
  # ulysse.corne.sh: static Zola site from github:ulyssecrn/website, served by
  # Caddy from the Nix store. Same path as calibre/jellyfin: a Pangolin resource
  # targets http://10.253.0.4:8090 over the `pangolin` WG interface, so there is
  # no *.corne.sh vhost in caddy.nix. Pangolin's own auth must be OFF.
  # Update: nix flake update website && nrs
  services.ulysse-site = {
    enable = true;
    port = 8090;
    firewallInterface = "pangolin";
  };
}
