{ config, lib, pkgs, ... }:

{
  # Firecrawl — web scraper that turns URLs into LLM-ready markdown.
  # https://github.com/firecrawl/firecrawl
  #
  # LibreChat's webSearch needs a scraper: SearXNG alone returns titles +
  # snippets, which LibreChat refuses to use as "real" results. Firecrawl
  # visits each SearXNG hit, extracts the main content, and hands LibreChat
  # something it can actually feed the model.
  #
  # Five containers, all on the default podman bridge (DNS-by-name works
  # because containers.nix sets dns_enabled = true). Only the api is
  # reachable from the host, on :3002.
  #
  # Auth: USE_DB_AUTHENTICATION = false → firecrawl ignores Bearer tokens,
  # so LibreChat's FIRECRAWL_API_KEY can be a placeholder. Trust boundary
  # is the host + podman bridge; we never expose firecrawl outside genghis.
  #
  # Sensitive values live outside the nix store at /var/lib/firecrawl/env.
  # Generate once:
  #   sudo install -d -m 0700 -o root -g root /var/lib/firecrawl
  #   {
  #     echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)"
  #     echo "BULL_AUTH_KEY=$(openssl rand -hex 32)"
  #   } | sudo tee /var/lib/firecrawl/env > /dev/null
  #   sudo chmod 0600 /var/lib/firecrawl/env

  virtualisation.oci-containers.containers = {

    # ── api ──────────────────────────────────────────────────────────
    # The HTTP entrypoint LibreChat talks to. `harness.js --start-docker`
    # spawns the worker subprocesses inside this same container.
    firecrawl-api = {
      image = "ghcr.io/firecrawl/firecrawl:latest";
      cmd = [ "node" "dist/src/harness.js" "--start-docker" ];
      environment = {
        TZ = "Europe/Paris";
        HOST = "0.0.0.0";
        PORT = "3002";
        ENV = "local";

        # Wiring to the sidecars (override the compose defaults that
        # assume bare names like "redis" / "rabbitmq").
        REDIS_URL = "redis://firecrawl-redis:6379";
        REDIS_RATE_LIMIT_URL = "redis://firecrawl-redis:6379";
        NUQ_RABBITMQ_URL = "amqp://firecrawl-rabbitmq:5672";
        POSTGRES_HOST = "firecrawl-pg";
        POSTGRES_PORT = "5432";
        POSTGRES_USER = "postgres";
        POSTGRES_DB = "postgres";
        # POSTGRES_PASSWORD comes from the env file.
        PLAYWRIGHT_MICROSERVICE_URL =
          "http://firecrawl-playwright:3000/scrape";

        # Self-hosted: no API key validation. LibreChat sends a
        # placeholder that firecrawl ignores.
        USE_DB_AUTHENTICATION = "false";

        # Conservative concurrency — genghis has plenty of CPU but the
        # browser pool is the real cost ceiling.
        NUM_WORKERS_PER_QUEUE = "8";
        CRAWL_CONCURRENT_REQUESTS = "10";
        MAX_CONCURRENT_JOBS = "5";
        BROWSER_POOL_SIZE = "5";

        LOGGING_LEVEL = "info";
      };
      environmentFiles = [ "/var/lib/firecrawl/env" ];
      ports = [ "127.0.0.1:3002:3002" ];
      dependsOn = [
        "firecrawl-redis"
        "firecrawl-rabbitmq"
        "firecrawl-pg"
        "firecrawl-playwright"
      ];
      autoStart = true;
    };

    # ── playwright (headless browser) ─────────────────────────────────
    # Render-as-real-browser sidecar. Heavy: chromium + node, ~1 GB image.
    firecrawl-playwright = {
      image = "ghcr.io/firecrawl/playwright-service:latest";
      environment = {
        PORT = "3000";
        MAX_CONCURRENT_PAGES = "10";
        # Block media to keep RAM and bandwidth sane — we only want HTML.
        BLOCK_MEDIA = "true";
      };
      # /tmp/.cache is the playwright cache — keep it on tmpfs so it
      # doesn't leak onto the host fs across restarts.
      extraOptions = [
        "--tmpfs=/tmp/.cache:noexec,nosuid,size=1g"
      ];
      autoStart = true;
    };

    # ── redis ─────────────────────────────────────────────────────────
    # Rate limit + cache. State is fine to lose; no persistent volume.
    firecrawl-redis = {
      image = "docker.io/redis:alpine";
      cmd = [ "redis-server" "--bind" "0.0.0.0" ];
      autoStart = true;
    };

    # ── rabbitmq ──────────────────────────────────────────────────────
    # Job queue for nuq. State persists for in-flight jobs but is OK to
    # lose on full restart — firecrawl re-queues.
    firecrawl-rabbitmq = {
      image = "docker.io/rabbitmq:3-management";
      cmd = [ "rabbitmq-server" ];
      autoStart = true;
    };

    # ── nuq-postgres ──────────────────────────────────────────────────
    # Firecrawl's custom postgres image with their schema preloaded.
    # Holds extraction history + dedup state.
    firecrawl-pg = {
      image = "ghcr.io/firecrawl/nuq-postgres:latest";
      environment = {
        POSTGRES_USER = "postgres";
        POSTGRES_DB = "postgres";
        # POSTGRES_PASSWORD from env file.
      };
      environmentFiles = [ "/var/lib/firecrawl/env" ];
      volumes = [
        "/var/lib/firecrawl/pg:/var/lib/postgresql/data:rw"
      ];
      autoStart = true;
    };

  };

  systemd.tmpfiles.rules = [
    "d /var/lib/firecrawl 0700 root root - -"
    # Postgres in this image runs as UID 999 (debian default).
    "d /var/lib/firecrawl/pg 0700 999 999 - -"
  ];

  # Only the api port is exposed — and only on localhost so the host
  # firewall doesn't need to know. LibreChat reaches it via
  # host.containers.internal:3002 (the podman host-gateway).
}
