{ config, lib, pkgs, ... }:

{
  # Open WebUI — chat UI in front of the local llama.cpp server on this host.
  # llama.cpp exposes an OpenAI-compatible API on :8080 (see configuration.nix),
  # so we point open-webui's OPENAI_API_BASE_URL there. Container's internal
  # port is 8080; we publish on host port 8050 to avoid colliding with llama.
  #
  # If you also want to add the real OpenAI cloud endpoint, do it through the
  # admin UI (Settings → Connections) — open-webui persists it to its sqlite.
  # That keeps your real OPENAI_API_KEY out of the repo and out of the env.

  virtualisation.oci-containers.containers.open-webui = {
    image = "ghcr.io/open-webui/open-webui:main";
    environment = {
      TZ = "Europe/Paris";
      ENV = "prod";
      PORT = "8080";

      # Disable ollama path — we're using llama.cpp via the OpenAI-compat API
      ENABLE_OLLAMA_API = "false";

      # llama.cpp on this host's LAN address. host.containers.internal would
      # also work but pinning the LAN IP avoids podman-version surprises.
      OPENAI_API_BASE_URL = "http://10.10.10.9:8080/v1";
      OPENAI_API_KEY = "sk-no-key-needed-llamacpp";  # llama.cpp ignores it

      ENABLE_RAG_LOCAL_WEB_FETCH = "true";
      SCARF_NO_ANALYTICS = "true";
      DO_NOT_TRACK = "true";
      ANONYMIZED_TELEMETRY = "false";

      # Web search via SearXNG (running natively on the host at 127.0.0.1:8888).
      # host.containers.internal resolves to the host gateway thanks to the
      # --add-host extraOption below.
      ENABLE_WEB_SEARCH = "true";
      WEB_SEARCH_ENGINE = "searxng";
      SEARXNG_QUERY_URL = "http://host.containers.internal:8888/search?q=<query>&format=json";
    };
    volumes = [
      "/var/lib/open-webui:/app/backend/data:rw"
    ];
    ports = [ "8050:8080" ];
    extraOptions = [
      "--add-host=host.containers.internal:host-gateway"
      # The podman default bridge is IPv4-only, but glibc still resolves
      # AAAA records → Python's requests tries IPv6 first and every fetch
      # in langchain's WebBaseLoader fails before falling back. The
      # sysctls turn off IPv6 sockets in the container's netns, and the
      # dns-option tells glibc not to even query AAAA records.
      "--sysctl=net.ipv6.conf.all.disable_ipv6=1"
      "--sysctl=net.ipv6.conf.default.disable_ipv6=1"
      "--dns-option=no-aaaa"
    ];
    autoStart = true;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/open-webui 0755 root root - -"
  ];

  networking.firewall.allowedTCPPorts = [ 8050 ];
}
