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
  # connections — those hold API keys and live in the state dir (settings.json +
  # the SQLite DB), set once through the web UI on :5055:
  #   - pick Jellyfin as the media server, point it at the native jellyfin (:8096)
  #   - add Radarr (:7878) and Sonarr (:8989) with their API keys
  # Keeping that out of Nix is intentional: secrets stay off the store.
  #
  # State lives in /var/lib/jellyseerr, NOT the usual /srv/appdata: the module
  # runs as a DynamicUser under ProtectSystem=strict and only whitelists its
  # StateDirectory for writes (systemd auto-creates + chowns it to the volatile
  # uid). Pointing configDir at /srv/appdata gives EROFS — that path stays
  # read-only in the unit's namespace. The request DB here is cheaply
  # rebuildable (re-link Jellyfin + the arrs), so it's not worth the static-user
  # gymnastics to relocate it.
  services.seerr = {
    enable = true;
    openFirewall = true;  # opens :5055
  };
}
