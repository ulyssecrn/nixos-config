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
      # No version pin — uses the bundled playwright in the image. With a
      # version pin (@1.58), npx fetches latest 1.58.x and skews the
      # Chromium-binary path expectation, breaking connect-time launch.
      "npx playwright run-server --port 3000 --host 0.0.0.0"
    ];
    autoStart = true;
  };
}
