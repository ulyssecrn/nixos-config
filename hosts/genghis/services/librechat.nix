{ config, lib, pkgs, ... }:

let
  # librechat.yaml — endpoints + memory config. Lives in the nix store
  # (no secrets here, only structure) and gets bind-mounted into the
  # container. Bumping the version key is what triggers LibreChat to
  # re-read it on container restart.
  librechatYaml = pkgs.writeText "librechat.yaml" ''
    version: 1.2.4
    cache: true

    # ── Endpoints ────────────────────────────────────────────────────
    # Reuse this host's llama.cpp (OpenAI-compat at :8080).
    endpoints:
      custom:
        - name: "llamacpp"
          apiKey: "sk-no-key-needed-llamacpp"
          baseURL: "http://10.10.10.9:8080/v1"
          models:
            default: ["Qwen3.6-27B-Q4_K_M.gguf"]
            fetch: true
          titleConvo: true
          titleModel: "current_model"
          modelDisplayLabel: "Qwen3.6"

    # ── Memory ───────────────────────────────────────────────────────
    # Per-user key/value memory (NOT vector-based — no pgvector needed).
    # Users toggle memory in the chat UI. The "agent" decides what to
    # remember from each conversation — we point it at the same local
    # llama.cpp endpoint so nothing leaves the host.
    memory:
      disabled: false
      personalize: true
      messageWindowSize: 5
      charLimit: 10000
      agent:
        provider: "llamacpp"
        model: "Qwen3.6-27B-Q4_K_M.gguf"
  '';

in
{
  # LibreChat — chat UI with built-in memory feature.
  # https://www.librechat.ai
  #
  # Minimal stack for memory: api + mongodb. Skip meilisearch (only adds
  # message-history search) and pgvector/rag_api (only needed for document
  # RAG, which we're not using).
  #
  # Sensitive values live outside the nix store at /var/lib/librechat/env.
  # Generate the four secrets once with:
  #   {
  #     echo "JWT_SECRET=$(openssl rand -hex 32)"
  #     echo "JWT_REFRESH_SECRET=$(openssl rand -hex 32)"
  #     echo "CREDS_KEY=$(openssl rand -hex 32)"
  #     echo "CREDS_IV=$(openssl rand -hex 16)"
  #   } | sudo tee /var/lib/librechat/env > /dev/null
  #   sudo chmod 0600 /var/lib/librechat/env

  virtualisation.oci-containers.containers = {

    librechat = {
      image = "ghcr.io/danny-avila/librechat-dev:latest";
      environment = {
        TZ = "Europe/Paris";
        HOST = "0.0.0.0";
        PORT = "3080";
        NODE_ENV = "production";

        MONGO_URI = "mongodb://librechat-mongo:27017/LibreChat";

        # Allow user signup; turn off later if you want a closed instance.
        ALLOW_REGISTRATION = "true";
        ALLOW_EMAIL_LOGIN = "true";
        ALLOW_SOCIAL_LOGIN = "false";
        ALLOW_SOCIAL_REGISTRATION = "false";

        # Reached via caddy at http://librechat.corne.sh. Same fix as
        # odysseus — JS bootstrap silently fails if origin isn't allowed.
        DOMAIN_CLIENT = "http://librechat.corne.sh";
        DOMAIN_SERVER = "http://librechat.corne.sh";
        ALLOWED_ORIGINS = "http://librechat.corne.sh,http://10.10.10.9:3080";

        # Tells LibreChat to read librechat.yaml from this path inside
        # the container. The file is bind-mounted below.
        CONFIG_PATH = "/app/librechat.yaml";

        # No telemetry.
        SCARF_NO_ANALYTICS = "true";
        DO_NOT_TRACK = "true";
      };
      environmentFiles = [ "/var/lib/librechat/env" ];
      volumes = [
        # Static config — librechat.yaml from the nix store.
        "${librechatYaml}:/app/librechat.yaml:ro"
        # Runtime state (uploads, images, logs).
        "/var/lib/librechat/uploads:/app/uploads:rw"
        "/var/lib/librechat/images:/app/client/public/images:rw"
        "/var/lib/librechat/logs:/app/api/logs:rw"
      ];
      ports = [ "3080:3080" ];
      dependsOn = [ "librechat-mongo" ];
      extraOptions = [
        "--add-host=host.containers.internal:host-gateway"
        "--dns-option=no-aaaa"
      ];
      autoStart = true;
    };

    librechat-mongo = {
      image = "docker.io/mongo:8.0.20";
      # No host port — only librechat reaches it via the podman bridge.
      volumes = [
        "/var/lib/librechat/mongo:/data/db:rw"
      ];
      autoStart = true;
    };

  };

  systemd.tmpfiles.rules = [
    "d /var/lib/librechat 0700 root root - -"
    "d /var/lib/librechat/uploads 0755 root root - -"
    "d /var/lib/librechat/images 0755 root root - -"
    "d /var/lib/librechat/logs 0755 root root - -"
    "d /var/lib/librechat/mongo 0755 root root - -"
  ];

  networking.firewall.allowedTCPPorts = [ 3080 ];
}
