{ config, lib, pkgs, ... }:

{
  # LUKS root unlocked by a keyfile baked into the initrd, so the box comes back
  # unattended after a power cut (it runs Uptime Kuma — it can't wait on a
  # passphrase). The M900's TPM is 1.2-only, which systemd-cryptenroll can't
  # use.
  #
  # The initrd sits on the unencrypted ESP of the same disk, so this is NOT
  # protection at rest — anyone holding the disk holds the key. It keeps the
  # LUKS container so real encryption is one `luksKillSlot` away (e.g. once a
  # Tang server exists on this LAN → boot.initrd.clevis), no reinstall.
  # The passphrase stays enrolled as the fallback.
  #
  # Bootstrap once on lafayette, BEFORE the first rebuild with this file
  # (the initrd build reads the key from here):
  #   sudo mkdir -p /etc/secrets/initrd
  #   sudo dd if=/dev/urandom of=/etc/secrets/initrd/cryptroot.key bs=64 count=1
  #   sudo chmod 400 /etc/secrets/initrd/cryptroot.key
  #   sudo cryptsetup luksAddKey /dev/disk/by-partlabel/lafayette-root /etc/secrets/initrd/cryptroot.key

  boot.initrd.systemd.enable = true;

  boot.initrd.secrets."/cryptroot.key" = "/etc/secrets/initrd/cryptroot.key";

  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/disk/by-partlabel/lafayette-root";
    allowDiscards = true;
    keyFile = "/cryptroot.key";
  };
}
