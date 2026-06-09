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

    # ── Model specs — unlock the full 192K context window ────────────
    # Without an explicit maxContextTokens, LibreChat caps custom
    # endpoints at ~39K. modelSpecs lets us declare the real budget
    # AND ships a default preset so we don't have to retweak each chat.
    modelSpecs:
      prioritize: true
      list:
        - name: "qwen3.6-27b-local"
          label: "Qwen3.6-27B (local)"
          default: true
          description: "Local Qwen3.6 via llama.cpp, 138k context + vision"
          preset:
            endpoint: "llamacpp"
            model: "Qwen3.6-27B-Q4_K_M.gguf"
            # Server reserves -c 150000 but per club-3090 bench data the
            # *fillable* ceiling is ~138K before edge OOM. Match that.
            maxContextTokens: 138000
            max_tokens: 8192
            temperature: 0.6
            top_p: 0.95
            # Qwen3.6 was trained on ChatGPT outputs and inherits its
            # citation tokens (turn0search1, turn0news0…). LibreChat
            # doesn't post-process those, so they leak as raw text.
            # Force standard markdown citations instead.
            promptPrefix: |
              When citing web search results, use standard markdown links: [source name](url) inline, and a "Sources" list at the end. Never emit citation tokens like "turn0search1", "turn0news0", or "[oai_citation]" — those are ChatGPT-internal markers that won't render here.

    # ── Memory ───────────────────────────────────────────────────────
    # Per-user key/value memory (NOT vector-based — uses Mongo, not
    # pgvector). Users toggle memory in the chat UI. The "agent" decides
    # what to remember — pointed at the same local llama.cpp.
    memory:
      disabled: false
      personalize: true
      messageWindowSize: 5
      charLimit: 10000
      agent:
        provider: "llamacpp"
        model: "Qwen3.6-27B-Q4_K_M.gguf"

    # ── Web search ───────────────────────────────────────────────────
    # SearXNG (host-native at :8888) returns the candidate URLs; Firecrawl
    # (self-hosted in firecrawl.nix at :3002) scrapes each into markdown.
    # No reranker — bge-small-en-v1.5 via TEI is for RAG, and the public
    # rerankers (jina/cohere) all want a paid key.
    #
    # Literal URLs in this block are silently ignored — LibreChat only
    # picks them up via env-var substitution, which is why the UI was
    # re-prompting for the SearXNG URL on every search. The two single
    # quotes before each dollar sign below escape nix interpolation so
    # the literal placeholder reaches LibreChat's yaml parser intact.
    webSearch:
      searchProvider: "searxng"
      searxngInstanceUrl: "''${SEARXNG_INSTANCE_URL}"
      scraperProvider: "firecrawl"
      firecrawlApiUrl: "''${FIRECRAWL_API_URL}"
      firecrawlApiKey: "''${FIRECRAWL_API_KEY}"
      firecrawlOptions:
        formats: ["markdown"]
        onlyMainContent: true
        blockAds: true
        skipTlsVerification: true
        parsePDF: true
        storeInCache: true
        timeout: 40000
      rerankerType: "none"

    # ── Summarization ────────────────────────────────────────────────
    # When a chat approaches maxContextTokens, summarize older messages
    # via Qwen3.6 (same local model — free, just adds latency once).
    # Keeps the conversation's thread instead of silently truncating.
    summarization:
      provider: "llamacpp"
      model: "Qwen3.6-27B-Q4_K_M.gguf"
      maxSummaryTokens: 4096      # cap the summary itself at 4K
      reserveRatio: 0.05          # always keep 5% headroom for new turns
      trigger:
        type: "token_ratio"
        value: 0.8                # kick in at 80% of maxContextTokens
      contextPruning:
        enabled: true
        keepLastAssistants: 3     # keep the 3 most recent assistant turns verbatim
        softTrimRatio: 0.3
        hardClearRatio: 0.5
        minPrunableToolChars: 50000
        softTrim:
          maxChars: 4000
          headChars: 1500
          tailChars: 1500
        hardClear:
          enabled: true
          placeholder: "[Old tool result content cleared]"
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
  # Generate the secrets once (POSTGRES_PASSWORD added for pgvector RAG):
  #   {
  #     echo "JWT_SECRET=$(openssl rand -hex 32)"
  #     echo "JWT_REFRESH_SECRET=$(openssl rand -hex 32)"
  #     echo "CREDS_KEY=$(openssl rand -hex 32)"
  #     echo "CREDS_IV=$(openssl rand -hex 16)"
  #     echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)"
  #   } | sudo tee /var/lib/librechat/env > /dev/null
  #   sudo chmod 0600 /var/lib/librechat/env

  virtualisation.oci-containers.containers = {

    librechat = {
      image = "ghcr.io/danny-avila/librechat:latest";
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

        SESSION_COOKIE_SECURE = "false";

        # Web search — interpolated into librechat.yaml's webSearch block.
        SEARXNG_INSTANCE_URL = "http://host.containers.internal:8888";
        FIRECRAWL_API_URL = "http://host.containers.internal:3002";
        # Self-hosted firecrawl runs with USE_DB_AUTHENTICATION=false, so
        # any non-empty value is accepted. The "key" is unused on the wire.
        FIRECRAWL_API_KEY = "self-hosted-no-key-needed";

        # Tells LibreChat to read librechat.yaml from this path inside
        # the container. The file is bind-mounted below.
        CONFIG_PATH = "/app/librechat.yaml";

        # RAG — talks to the rag_api sidecar over the podman bridge.
        RAG_API_URL = "http://librechat-rag-api:8000";

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
      dependsOn = [ "librechat-mongo" "librechat-rag-api" ];
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

    # ── RAG stack ────────────────────────────────────────────────────
    # Document upload → chunk → embed → store in pgvector.
    # Query time → retrieve top-k chunks → inject into prompt.

    librechat-vectordb = {
      image = "docker.io/pgvector/pgvector:0.8.0-pg15-trixie";
      environment = {
        POSTGRES_DB = "librechat_rag";
        POSTGRES_USER = "librechat";
        # POSTGRES_PASSWORD comes from the env file.
      };
      environmentFiles = [ "/var/lib/librechat/env" ];
      volumes = [
        "/var/lib/librechat/pgvector:/var/lib/postgresql/data:rw"
      ];
      autoStart = true;
    };

    # text-embeddings-inference — fast local embeddings, CPU-only so it
    # doesn't fight llama.cpp for the GPU. bge-small-en-v1.5 is ~30 MB
    # of weights, very strong quality for the size.
    librechat-tei = {
      image = "ghcr.io/huggingface/text-embeddings-inference:cpu-latest";
      cmd = [ "--model-id" "BAAI/bge-small-en-v1.5" ];
      volumes = [
        "/var/lib/librechat/tei-cache:/data:rw"
      ];
      autoStart = true;
    };

    librechat-rag-api = {
      # NOT the *-lite variant — lite ships only openai embeddings and
      # crashes on huggingfacetei with ModuleNotFoundError.
      image = "ghcr.io/danny-avila/librechat-rag-api-dev:latest";
      environment = {
        DB_HOST = "librechat-vectordb";
        DB_PORT = "5432";
        POSTGRES_DB = "librechat_rag";
        POSTGRES_USER = "librechat";
        # POSTGRES_PASSWORD from env file.

        EMBEDDINGS_PROVIDER = "huggingfacetei";
        EMBEDDINGS_MODEL = "BAAI/bge-small-en-v1.5";
        # Point rag_api at the TEI sidecar over the podman bridge.
        HF_EMBED_URL = "http://librechat-tei";
      };
      environmentFiles = [ "/var/lib/librechat/env" ];
      dependsOn = [ "librechat-vectordb" "librechat-tei" ];
      autoStart = true;
    };

  };

  systemd.tmpfiles.rules = [
    "d /var/lib/librechat 0700 root root - -"
    # LibreChat's container runs as UID 1000 (node user); these bind mounts
    # need matching ownership or every upload/import EACCES-crashes the app.
    "d /var/lib/librechat/uploads 0755 1000 1000 - -"
    "d /var/lib/librechat/images 0755 1000 1000 - -"
    "d /var/lib/librechat/logs 0755 1000 1000 - -"
    "d /var/lib/librechat/mongo 0755 root root - -"
    # pgvector image runs postgres as UID 999.
    "d /var/lib/librechat/pgvector 0700 999 999 - -"
    "d /var/lib/librechat/tei-cache 0755 1000 1000 - -"
  ];

  networking.firewall.allowedTCPPorts = [ 3080 ];
}
