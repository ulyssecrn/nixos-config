{ config, lib, pkgs, ... }:

{
  # Hermes — Nous Research's agentic assistant.
  # https://hermes-agent.nousresearch.com/docs
  #
  # WHY container mode (not the native systemd service):
  # Hermes is an *agent* — it runs shell commands, does browser automation
  # and installs its own tools at runtime. The module's `container.enable`
  # runs the whole thing inside a mutable Ubuntu OCI container (Nix-built
  # binary bind-mounted read-only from /nix/store), so:
  #   - a rogue tool call is boxed in the container, not on the NixOS host
  #   - the agent can pip/npm/apt-install freely inside that box (the native
  #     mode is immutable and those would fail)
  #   - config still lives here, declaratively.
  # Backend is podman to match the rest of genghis (system/profiles/x86/
  # containers.nix); native mode would also pull in docker, which we avoid.
  #
  # WHY no GPU flag: Hermes does no inference itself — it points at the
  # existing llama.cpp OpenAI endpoint on the host (:8080/v1). The 3090 Ti
  # stays entirely with llama.cpp. (Add `--gpus all` under container.
  # extraOptions only if you later want Hermes doing its own GPU work,
  # e.g. local whisper STT.)
  #
  # Secrets (the placeholder API key llama.cpp requires) live outside the
  # nix store at /var/lib/hermes/env. Create once:
  #   sudo install -d -m 0700 /var/lib/hermes
  #   echo 'OPENAI_API_KEY=sk-local-unused' | sudo tee /var/lib/hermes/env
  #   sudo chmod 0600 /var/lib/hermes/env
  #
  # NB: Nix/NixOS is a Tier-2 ("best-effort") target for Hermes and this
  # module is young — after adding the flake input, sanity-check the exact
  # option names it exposes with:
  #   nix eval .#nixosConfigurations.genghis.options.services.hermes-agent \
  #     --apply builtins.attrNames
  # and adjust below if any differ from the docs.

  services.hermes-agent = {
    enable = true;

    # Put a `hermes` wrapper on the host PATH that transparently execs into
    # the managed container (all flags forwarded). Without this the binary
    # only exists inside the container under /data and isn't callable from
    # the host — so `hermes --tui` on genghis "just works" with this on.
    addToSystemPackages = true;

    # ── Isolation ────────────────────────────────────────────────────
    container = {
      enable = true;
      backend = "podman";
      image = "ubuntu:24.04";
      # Symlinks host ~/.hermes ↔ container state so the host CLI shares
      # sessions/config/memories with the containerised agent.
      hostUsers = [ "ucorne" ];
      # Give the agent a host workspace it can read/write project files in.
      # extraVolumes = [ "/srv/hermes/projects:/projects:rw" ];
    };

    # ── Model: the local llama.cpp on this same host ─────────────────
    # We target the host's stable LAN IP rather than host.containers.internal
    # so it doesn't depend on the module wiring a host-gateway alias — the
    # podman bridge NATs out to 10.10.10.9 and llama-cpp's openFirewall opens
    # :8080. llama.cpp ignores the `model` field (single loaded model), so its
    # value is cosmetic; the api_key is only there because OpenAI clients
    # insist on a non-empty one (comes from environmentFiles).
    settings = {
      model = {
        # `custom` = a self-hosted OpenAI-compatible server reached via
        # base_url. `openai` would mean the real OpenAI API (hence the
        # "unknown provider" only shows once it tries to init that client).
        provider = "custom";
        default  = "Qwen3.6-27B-Q4_K_M";         # cosmetic — llama.cpp ignores it
        base_url = "http://10.10.10.9:8080/v1";
        api_key  = "none";                        # llama.cpp ignores it; placeholder keeps the client happy
      };

      # Shell commands run *inside* this (already isolated) container — the
      # whole point of container mode. Don't set this to "docker"/"ssh".
      terminal = {
        backend = "local";
        timeout = 180;
      };

      # Sensible defaults; tune once it's running.
      agent.max_turns = 60;
      memory.memory_enabled = true;
    };

    # ── Web dashboard (behind atilla's caddy, like the other services) ──
    # These land in the container's .env (the module seeds `environment` +
    # `environmentFiles` there) and are read by the dashboard launched in the
    # `hermes-dashboard` unit below. A non-loopback bind is mandatory-auth
    # since the June-2026 hardening (`--insecure` is a no-op), so the built-in
    # `basic` provider is on: username here (non-secret), password in the env
    # file. public_url gives the login/callback logic the real proxied origin.
    # NB `HERMES_DASHBOARD=1` auto-supervision is s6-image-only — no effect in
    # this ubuntu+nix container — hence we start the dashboard explicitly.
    environment = {
      HERMES_DASHBOARD_BASIC_AUTH_USERNAME = "ucorne";
      HERMES_DASHBOARD_PUBLIC_URL = "http://hermes.corne.sh";
    };

    # ── Secrets & state ──────────────────────────────────────────────
    environmentFiles = [ "/var/lib/hermes/env" ];
    stateDir = "/var/lib/hermes";
    restart = "always";
  };

  # The dashboard listens on :9119 (host netns via --network=host). Open it on
  # the LAN so atilla's caddy can reverse-proxy hermes.corne.sh → 10.10.10.9:9119,
  # same as the other genghis services. Access is still gated by the dashboard's
  # own basic-auth login (LAN/Tailscale are trusted transports; the password is
  # the second factor for the one service that can drive an agent shell).
  networking.firewall.allowedTCPPorts = [ 9119 ];

  # The module's container is ubuntu+nix (no s6 supervisor), so the dashboard
  # isn't auto-started. Launch it by exec-ing the same binary the host `hermes`
  # wrapper uses (as the container's `hermes` user, per the module's
  # .container-mode metadata), bound to the LAN so caddy can reach it. Tied to
  # the gateway container's lifecycle via partOf/requires.
  systemd.services.hermes-dashboard = {
    description = "Hermes web dashboard (LAN-bound, behind atilla caddy)";
    after = [ "hermes-agent.service" ];
    requires = [ "hermes-agent.service" ];
    partOf = [ "hermes-agent.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 10;
      ExecStart = "${pkgs.podman}/bin/podman exec -u hermes hermes-agent /data/current-package/bin/hermes dashboard --host 0.0.0.0 --port 9119 --no-open";
    };
  };

  # The gateway container is rootful (its systemd unit runs as root), so a
  # rootless `podman` as ucorne can't see it — the host `hermes` wrapper
  # shells out to `sudo -n podman exec …` and would otherwise hang on a
  # password prompt. Grant passwordless podman to ucorne. This is
  # effectively passwordless root, but ucorne is already in `wheel`, so it
  # widens nothing meaningful on this single-admin box — it just drops the
  # prompt so the non-interactive `-n` call succeeds.
  security.sudo.extraRules = [{
    users = [ "ucorne" ];
    commands = [{
      command = "/run/current-system/sw/bin/podman";
      options = [ "NOPASSWD" ];
    }];
  }];
}
