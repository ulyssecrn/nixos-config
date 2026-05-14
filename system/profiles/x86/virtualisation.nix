{ config, pkgs, ... }:

{
  # ── Virtualisation (headless hypervisor stack) ──────────────────────
  # Safe to import on x86 desktops and servers alike. virt-manager (GUI)
  # and spice USB redirection live in desktop-x86.nix.
  users.groups.libvirtd.members = [ "ucorne" ];
  users.groups.kvm.members = [ "ucorne" ];

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };
}
