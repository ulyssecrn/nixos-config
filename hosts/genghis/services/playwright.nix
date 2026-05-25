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
    image = "mcr.microsoft.com/playwright:v1.49.1-noble";
    cmd = [
      "/bin/bash" "-c"
      "npx playwright run-server --port 3000 --host 0.0.0.0"
    ];
    autoStart = true;
  };
}
