{ ... }:

{
  # Seerr — media request + discovery front-end (the Feb-2026 merge of Overseerr
  # and Jellyseerr; `jellyseerr`/`overseerr` are now deprecated aliases). Browses
  # TMDB, shows what's already in the library, and hands requests to Radarr/Sonarr
  # to download. Talks to everything over HTTP APIs only — so unlike the *arr apps
  # it needs no media mounts and no 99:100 ownership; the module's own user is fine.
  #
  # The module is deliberately thin (enable/port/openFirewall/configDir/package).
  # There is NO declarative option for the Jellyfin link or the Radarr/Sonarr
  # connections — those hold API keys and live in configDir (settings.json + the
  # SQLite DB), set once through the web UI on :5055:
  #   - pick Jellyfin as the media server, point it at the native jellyfin (:8096)
  #   - add Radarr (:7878) and Sonarr (:8989) with their API keys
  # Keeping that out of Nix is intentional: secrets stay off the store.
  services.seerr = {
    enable = true;
    openFirewall = true;               # opens :5055
    configDir = "/srv/appdata/seerr";  # match the fleet's appdata convention
  };
}
