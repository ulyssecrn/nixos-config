{ lib, pkgs, ... }:

# Proton Mail Bridge — headless daemon that logs into Proton and exposes a LOCAL
# IMAP server (127.0.0.1:1143, + an SMTP one on :1025 we never wire) with its own
# bridge-generated credentials. Proton has no native IMAP; Bridge is the only path
# (a paid feature). The Hermes agent reaches it over loopback because its container
# runs --network=host; a read-only IMAP MCP (see hermes.nix) is the only consumer.
#
# Keychain: a server has no GNOME-keyring/KWallet, so Bridge's vault key is stored
# via `pass` backed by a passphrase-less GPG key under the state dir. That key is
# protected by filesystem perms only — the same trust level as the IMAP password
# we later drop in /var/lib/hermes/env, on a single-user box, so acceptable.
#
# One-time bring-up (run on genghis AFTER the first `nrs`; daemon must be STOPPED
# because Bridge single-locks its vault):
#   sudo systemctl stop protonmail-bridge
#   sudo -u protonmail-bridge HOME=/var/lib/protonmail-bridge \
#     GNUPGHOME=/var/lib/protonmail-bridge/gnupg \
#     PASSWORD_STORE_DIR=/var/lib/protonmail-bridge/password-store bash
#   # then, in that shell:
#   gpg --batch --passphrase '' --quick-gen-key protonmail-bridge default default never
#   pass init "$(gpg --list-keys --with-colons | awk -F: '/^fpr:/{print $10; exit}')"
#   protonmail-bridge --cli
#     >>> login          # Proton email + password + 2FA
#     >>> info           # prints IMAP host/port/username/password — copy these
#     >>> exit
#   exit
#   sudo systemctl start protonmail-bridge
# Then put the `info` IMAP username/password into /var/lib/hermes/env and `nrs`.

let
  stateDir = "/var/lib/protonmail-bridge";
  # NB: do NOT set XDG_{CONFIG,DATA,CACHE}_HOME here. Bridge stores its account
  # vault under those (defaulting to $HOME/.config etc.), and the one-time
  # interactive `login` runs with only HOME set — so overriding XDG for the daemon
  # points it at a DIFFERENT, empty vault dir than the login wrote to, and it
  # serves no account ("no such user" on every IMAP login). Let both use $HOME/.*.
  bridgeEnv = {
    HOME = stateDir;
    GNUPGHOME = "${stateDir}/gnupg";
    PASSWORD_STORE_DIR = "${stateDir}/password-store";
  };
in
{
  users.users.protonmail-bridge = {
    isSystemUser = true;
    group = "protonmail-bridge";
    home = stateDir;
    createHome = true;
    shell = pkgs.bashInteractive; # the one-time `login` is interactive (2FA)
  };
  users.groups.protonmail-bridge = { };

  environment.systemPackages = [ pkgs.protonmail-bridge pkgs.pass pkgs.gnupg ];

  # Pre-create the keychain dirs (0700) so gpg/pass work on a fresh machine
  # without a manual mkdir.
  systemd.tmpfiles.rules = [
    "d ${stateDir}/gnupg 0700 protonmail-bridge protonmail-bridge - -"
    "d ${stateDir}/password-store 0700 protonmail-bridge protonmail-bridge - -"
  ];

  systemd.services.protonmail-bridge = {
    description = "Proton Mail Bridge (headless IMAP/SMTP)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = bridgeEnv;
    # gpg + pass MUST be on the DAEMON's PATH, else Bridge can't use the `pass`
    # keychain helper, falls back to the (absent) D-Bus Secret Service, and runs
    # the vault UNENCRYPTED ("could not create keychain: no keychain"). NOT dbus:
    # we want SecretService to stay unavailable so Bridge settles on pass.
    path = [ pkgs.pass pkgs.gnupg ];
    serviceConfig = {
      User = "protonmail-bridge";
      Group = "protonmail-bridge";
      StateDirectory = "protonmail-bridge";
      StateDirectoryMode = "0700";
      ExecStart = "${lib.getExe pkgs.protonmail-bridge} --noninteractive --log-level info";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
}
