{ config, pkgs, ... }:

{
  # ── Gaming ──────────────────────────────────────────────────────────
  # gamescope is broken for now in steam
  # https://discourse.nixos.org/t/gamescope-refuses-to-work-with-steam/71417/23
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
  programs.steam = {
    enable = true;
    extest.enable = true; # controller mouse support on wayland
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = [
      pkgs.proton-ge-bin
    ];
    gamescopeSession.enable = true;
  };
}
