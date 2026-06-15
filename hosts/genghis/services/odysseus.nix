{ config, lib, pkgs, ... }:

let
  # Pinned upstream commit. Bump to upgrade; the rebuild service rebuilds
  # the image only when this SHA changes (idempotency check below).
  #   Find the latest with:
  #     git ls-remote https://github.com/pewdiepie-archdaemon/odysseus refs/heads/main
  odysseusRev = "73673258199b353f9b3e04da9b37ae95077e2c8b";

  imageTag = "localhost/odysseus:${odysseusRev}";
  imageRepo = "https://github.com/pewdiepie-archdaemon/odysseus.git";
in
{
  # Odysseus — self-hosted ChatGPT/Claude-style AI workspace.
  # https://github.com/pewdiepie-archdaemon/odysseus
  #
  # Reuses this host's:
  #   - llama.cpp (OpenAI-compat at :8080) → LLM_HOST
  #   - SearXNG  (host-native at :8888)   → SEARXNG_INSTANCE
  # Sidecar:
  #   - chromadb (vector store for the memory/skills system)
  #
  # Upstream doesn't publish a container image, so we build it here from the
  # pinned commit above via podman. First `nrs` after a SHA bump pauses for
  # ~3 min while the image builds; subsequent rebuilds are no-ops.
  #
  # Sensitive values live outside the nix store at /var/lib/odysseus/env.
  # Create once:
  #   sudo install -d -m 0700 -o root -g root /var/lib/odysseus
  #   sudo tee /var/lib/odysseus/env <<'EOF'
  #   ODYSSEUS_ADMIN_USER=ucorne
  #   ODYSSEUS_ADMIN_PASSWORD=<long random>
  #   # optional API keys (only set what you want enabled):
  #   # HF_TOKEN=...
  #   # SERPER_API_KEY=...
  #   # TAVILY_API_KEY=...
  #   # GOOGLE_API_KEY=...
  #   # DATA_BRAVE_API_KEY=...
  #   EOF
  #   sudo chmod 0600 /var/lib/odysseus/env

  # ── Image build ─────────────────────────────────────────────────────
  systemd.services.odysseus-image-build = {
    description = "Build odysseus container image from upstream (pinned)";
    wantedBy = [ "podman-odysseus.service" ];
    before = [ "podman-odysseus.service" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.podman pkgs.coreutils pkgs.git ];
    script = ''
      set -euo pipefail
      if podman image exists ${imageTag}; then
        echo "image ${imageTag} already present — skipping build"
        exit 0
      fi
      echo "building ${imageTag} from ${imageRepo}#${odysseusRev}"
      podman build -t ${imageTag} ${imageRepo}#${odysseusRev}
    '';
  };

  # ── Containers ──────────────────────────────────────────────────────
  virtualisation.oci-containers.containers = {

    odysseus = {
      image = imageTag;
      environment = {
        TZ = "Europe/Paris";

        # llama.cpp on this host's LAN IP — avoids podman-version surprises
        # with host.containers.internal.
        LLM_HOST = "10.10.10.9:8080";
        OPENAI_API_KEY = "sk-no-key-needed-llamacpp";  # llama.cpp ignores it

        # Sidecar chromadb — resolved by name on the podman default bridge.
        CHROMADB_HOST = "chromadb";
        CHROMADB_PORT = "8000";

        # Reuse host SearXNG (host-native at :8888) via the podman gateway.
        # The --add-host extraOption below wires host.containers.internal.
        SEARXNG_INSTANCE = "http://host.containers.internal:8888";

        # Auth on. Credentials come from the environmentFile below.
        AUTH_ENABLED = "true";
        LOCALHOST_BYPASS = "false";

        # Reached via caddy at http://odysseus.corne.sh (atilla → over
        # Tailscale → genghis:7000). ALLOWED_ORIGINS defaults to localhost
        # which makes the JS bootstrap fail silently behind a proxy — must
        # include the public origin here.
        ALLOWED_ORIGINS = "http://odysseus.corne.sh";

        # Telemetry off.
        ANONYMIZED_TELEMETRY = "FALSE";
        DO_NOT_TRACK = "true";

        PUID = "1000";
        PGID = "1000";
      };
      environmentFiles = [ "/var/lib/odysseus/env" ];
      volumes = [
        # /app/data holds app.db, memory.json, presets.json, uploads,
        # personal_docs, chroma (local cache), settings.json — all user state.
        "/var/lib/odysseus/data:/app/data:rw"
        "/var/lib/odysseus/logs:/app/logs:rw"
        # Hugging Face cache — shared across rebuilds so embedding models
        # don't redownload every time.
        "/var/lib/odysseus/hf-cache:/app/.cache/huggingface:rw"
      ];
      ports = [ "7000:7000" ];
      dependsOn = [ "chromadb" ];
      extraOptions = [
        "--add-host=host.containers.internal:host-gateway"
        # podman bridge is IPv4-only — force IPv4-only resolution so glibc
        # doesn't try AAAA first and stall on outbound HTTP.
        "--dns-option=no-aaaa"
      ];
      autoStart = true;
    };

    chromadb = {
      image = "docker.io/chromadb/chroma:latest";
      environment = {
        ANONYMIZED_TELEMETRY = "FALSE";
      };
      volumes = [
        "/var/lib/odysseus/chromadb:/chroma/chroma:rw"
      ];
      # No host port — odysseus reaches it via the podman bridge.
      autoStart = true;
    };

  };

  systemd.tmpfiles.rules = [
    "d /var/lib/odysseus 0700 root root - -"
    "d /var/lib/odysseus/data 0755 root root - -"
    "d /var/lib/odysseus/logs 0755 root root - -"
    "d /var/lib/odysseus/hf-cache 0755 root root - -"
    "d /var/lib/odysseus/chromadb 0755 root root - -"
  ];

  networking.firewall.allowedTCPPorts = [ 7000 ];
}
