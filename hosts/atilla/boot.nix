{ config, lib, pkgs, ... }:

{
  # One-passphrase boot:
  #   1. systemd-boot loads kernel + initrd
  #   2. initrd brings up r8169 NIC at 10.10.10.10 + sshd on :2222
  #   3. SSH from anywhere on the LAN/Tailscale → cryptsetup-askpass prompts
  #   4. Type LUKS root passphrase → cryptroot opens, root mounts
  #   5. systemd-cryptsetup@media1 opens media1 via keyfile on root
  #   6. zfs-import-tank imports tank; zfs-load-keys loads tank.key; datasets mount
  #   7. podman services start, containers come up

  # 15-minute window to decrypt luks before safe mode instead of default 90s
  boot.initrd.systemd.extraConfig = ''
    DefaultTimeoutStartSec=15min
  '';

  # ─── Initrd: NIC driver + SSH for remote LUKS unlock ───────────────────
  boot.initrd.availableKernelModules = [ "r8169" ];

  # Static IP in initrd (no DHCP). Format:
  #   ip=<client>::<gateway>:<netmask>::<device>:<autoconf>
  boot.kernelParams = [
    "ip=10.10.10.10::10.10.10.1:255.255.255.0::enp6s0:none"
  ];

  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;
      port = 2222;
      # Host key generated once on atilla (NOT in the nix store / repo):
      #   sudo mkdir -p /etc/secrets/initrd
      #   sudo ssh-keygen -t ed25519 -f /etc/secrets/initrd/ssh_host_ed25519_key -N ""
      hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
      # Reuse the same key authorized for normal SSH login
      authorizedKeys = config.users.users.ucorne.openssh.authorizedKeys.keys;
    };
  };

  # Unlock workflow on systemd stage 1 initrd:
  #   1. ssh atilla-initrd
  #   2. systemd-tty-ask-password-agent --query
  #   3. type LUKS root passphrase → boot continues

  # ─── media1 + media2 LUKS chain-unlock via keyfiles on encrypted root ──
  # Keyfiles live on the LUKS-encrypted root filesystem, only readable
  # after root mounts. systemd-cryptsetup@<name> opens each post-root.
  environment.etc."crypttab".text = ''
    media1 UUID=5b6f69f9-e86c-4c92-8ac8-28b214e99e02 /var/lib/luks-keys/media1.key luks,nofail
    media2 UUID=f60d2f69-3d09-4d62-a316-fcabe7bc530a /var/lib/luks-keys/media2.key luks,nofail
  '';

  fileSystems."/mnt/media1" = {
    device = "/dev/mapper/media1";
    fsType = "ext4";
    options = [ "nofail" "noatime" ];
  };

  fileSystems."/mnt/media2" = {
    device = "/dev/mapper/media2";
    fsType = "ext4";
    options = [ "nofail" "noatime" ];
  };

  # ─── mergerfs union: /mnt/media1 + /mnt/media2 → /srv/media ────────────
  # Policy summary:
  #   category.create=mfs   new files land on most-free-space branch
  #   minfreespace=50G      skip a branch once it's below 50G free
  #   moveonenospc=true     if a write fills a branch, migrate to another
  # depends ensures both branches are mounted before mergerfs assembles.
  fileSystems."/srv/media" = {
    device = "/mnt/media1:/mnt/media2";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "cache.files=partial"
      "dropcacheonclose=true"
      "category.create=mfs"
      "minfreespace=50G"
      "moveonenospc=true"
      "fsname=mergerfs"
      "nofail"
    ];
    depends = [ "/mnt/media1" "/mnt/media2" ];
  };

  environment.systemPackages = [ pkgs.mergerfs ];

  # ─── tank ZFS auto-import + auto-key-load ──────────────────────────────
  # extraPools causes zfs-import-tank.service to import at boot.
  # The custom oneshot below runs `zfs load-key -a` between import and mount
  # so the file-backed keylocation gets read (keylocation=file:///... was
  # set when creating the pool).
  boot.zfs.extraPools = [ "tank" ];

  systemd.services."zfs-load-keys" = {
    description = "Load ZFS encryption keys from keylocation files";
    wantedBy = [ "zfs-mount.service" ];
    before = [ "zfs-mount.service" ];
    after = [ "zfs-import-tank.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.zfs}/bin/zfs load-key -a || true
    '';
  };
}
