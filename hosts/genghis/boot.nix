{ config, lib, pkgs, ... }:

{
  # Remote LUKS unlock at boot:
  #   1. systemd-boot loads kernel + initrd
  #   2. initrd brings up igb NIC (enp5s0) at 10.10.10.9 + sshd on :2222
  #   3. ssh genghis-initrd → systemd-tty-ask-password-agent --query
  #   4. type LUKS root passphrase → cryptroot opens, root mounts

  # already systemd by default but set it for safety
  boot.initrd.systemd.enable = true;

  # 15-minute window to decrypt luks before safe mode instead of default 90s
  boot.initrd.systemd.settings.Manager.DefaultTimeoutStartSec = "15min";

  # ─── Initrd: NIC driver + SSH for remote LUKS unlock ───────────────────
  # Intel I210/I211/I350 family — Intel NIC is the primary path. If the
  # cable's ever in the Realtek port (enp6s0f1, r8169), initrd can't reach
  # the network and remote unlock fails; recovery is physical-access only.
  boot.initrd.availableKernelModules = [ "igb" ];

  # Static IP in initrd (no DHCP). Format:
  #   ip=<client>::<gateway>:<netmask>::<device>:<autoconf>
  boot.kernelParams = [
    "ip=10.10.10.9::10.10.10.1:255.255.255.0::enp5s0:none"
  ];

  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;
      port = 2222;
      # Host key generated once on genghis (NOT in the nix store / repo):
      #   sudo mkdir -p /etc/secrets/initrd
      #   sudo ssh-keygen -t ed25519 -f /etc/secrets/initrd/ssh_host_ed25519_key -N ""
      hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
      # Reuse the same key authorized for normal SSH login
      authorizedKeys = config.users.users.ucorne.openssh.authorizedKeys.keys;
    };
  };

  # Unlock workflow on systemd stage 1 initrd:
  #   1. ssh genghis-initrd
  #   2. systemd-tty-ask-password-agent --query (auto-run via ssh alias)
  #   3. type LUKS root passphrase → boot continues
}
