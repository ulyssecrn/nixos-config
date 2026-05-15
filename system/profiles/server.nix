{ config, lib, pkgs, ... }:

{
  # ── Logging ─────────────────────────────────────────────────────────
  # Cap journal size — long-running hosts shouldn't fill disk with logs.
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    SystemMaxFileSize=50M
  '';

  # ── Resilience ──────────────────────────────────────────────────────
  # Headless hosts: reboot on kernel panic so they recover unattended.
  boot.kernel.sysctl = {
    "kernel.panic" = 10;
    "kernel.panic_on_oops" = 1;
  };
}
