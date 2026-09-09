{ config, lib, options, pkgs, ... }:

{
  # ── Logging ─────────────────────────────────────────────────────────
  # Cap journal size — long-running hosts shouldn't fill disk with logs.
  # nixpkgs dropped services.journald.extraConfig in favour of the
  # structured settings.Journal; hannibal's pinned stable nixpkgs still
  # only knows extraConfig, so pick whichever this host's nixpkgs provides.
  services.journald =
    if options.services.journald ? settings then {
      settings.Journal = {
        SystemMaxUse = "500M";
        SystemMaxFileSize = "50M";
      };
    } else {
      extraConfig = ''
        SystemMaxUse=500M
        SystemMaxFileSize=50M
      '';
    };

  # ── Resilience ──────────────────────────────────────────────────────
  # Headless hosts: reboot on kernel panic so they recover unattended.
  boot.kernel.sysctl = {
    "kernel.panic" = 10;
    "kernel.panic_on_oops" = 1;
  };
}
