{ config, lib, pkgs, ... }:

{
  # Headless Chromium server for open-webui's web loader. Open-webui connects
  # to it over WebSocket (PLAYWRIGHT_WS_URL=ws://playwright:3000) and uses it
  # to render JS-heavy pages and return clean text — way better than the
  # default aiohttp-WebBaseLoader, which currently fails silently for us.
  #
  # Both containers sit on podman's default network (dns_enabled), so the
  # hostname "playwright" resolves between them — no port needs to be
  # published to the host.
  virtualisation.oci-containers.containers.playwright = {
    # Image version MUST match open-webui's Python playwright client version
    # (check: `sudo podman exec open-webui pip show playwright | grep Version`).
    # The image ships matching playwright + matching Chromium binaries at the
    # paths the client expects. If you bump one, bump both.
    image = "mcr.microsoft.com/playwright:v1.58.0-noble";
    cmd = [
      "/bin/bash" "-c"
      # Microsoft's image only ships Chromium at /ms-playwright — the JS
      # playwright pkg has to be brought in via npx. Pin EXACT version
      # (1.58.0) to match the image's Chromium build AND open-webui's
      # Python client. Both `npx playwright run-server` (no pin → latest
      # = 1.60) and `playwright@1.58` (→ latest 1.58.x = 1.58.2) break,
      # the former on client/server, the latter on chromium-path.
      "npx -y playwright@1.58.0 run-server --port 3000 --host 0.0.0.0"
    ];
    autoStart = true;
  };
}
