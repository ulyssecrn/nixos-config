{ config, pkgs, ... }:

{
  # ── Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    unityhub
  ];

  # ── Hardware ────────────────────────────────────────────────────────
  # Ledger wallet
  hardware.ledger.enable = true;

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

  # ── Virtualisation ──────────────────────────────────────────────────
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["ucorne"];
  users.groups.kvm.members = [ "ucorne" ];

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };
  virtualisation.spiceUSBRedirection.enable = true;
}
