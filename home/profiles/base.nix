{ config, pkgs, ... }:

{
  # ── Imports ─────────────────────────────────────────────────────────
  imports = [
    ../modules/shell.nix
    ../modules/neovim.nix
    ../modules/btop.nix
    ../modules/tmux.nix
  ];

  # ── User ────────────────────────────────────────────────────────────
  home.username = "ucorne";
  home.homeDirectory = "/home/ucorne";

  # ── Packages ────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # CLI tools
    eza                              # ls replacement
    nnn                              # terminal file manager
    nmap
    which
    tree
    gawk
    fastfetch
    yt-dlp
    wget
    traceroute
    dnsutils

    # Archive tools
    zip
    unzip
    p7zip
    xz
    gnutar

    # Monitoring tools
    lm_sensors                       # sensors
    usbutils                         # lsusb
  ];

  # ── Git ─────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Ulysse Corne";
        email = "ulysse@corne.sh";
      };
      pull.rebase = true;
      init.defaultBranch = "main";
    };
    ignores = [
      ".venv"
      ".envrc"
      ".vscode"
      ".nvim"
      ".claude"
      # LaTeX
      "*.aux"
      "*.fdb_latexmk"
      "*.fls"
      "*.log"
      "*.synctex.gz"
      "**/__pycache__/"
    ];
  };

  # ── SSH ─────────────────────────────────────────────────────────────
  programs.ssh = {
    enable = true;
    package = pkgs.openssh_gssapi;
    settings = {
      forwardAgent = false;
      compression = false;
      serverAliveInterval = 0;
      serverAliveCountMax = 3;
      extraOptions = {
        AddKeysToAgent = "no";
        HashKnownHosts = "no";
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
    };

    matchBlocks = {
      "pikvm-genghis" = {
        hostname = "10.10.10.8";
        user = "root";
      };
      "genghis" = {
        hostname = "10.10.10.9";
        user = "ucorne";
        forwardAgent = true;
      };
      "genghis-realtek" = {
        hostname = "10.10.10.7";
        user = "ucorne";
        forwardAgent = true;
      };
      "genghis-initrd" = {
        hostname = "10.10.10.9";
        port = 2222;
        user = "root";
        userKnownHostsFile = "~/.ssh/known_hosts_initrd";
        extraOptions = {
          RemoteCommand = "systemd-tty-ask-password-agent --query";
          RequestTTY = "yes";
        };
      };
      "atilla" = {
        hostname = "10.10.10.10";
        user = "ucorne";
        forwardAgent = true;
      };
      "atilla-initrd" = {
        hostname = "10.10.10.10";
        port = 2222;
        user = "root";
        # Separate known_hosts: initrd has a different host key than the
        # post-boot sshd, so without this the client would yell about a
        # changed key every reboot.
        userKnownHostsFile = "~/.ssh/known_hosts_initrd";
        # Auto-run the LUKS passphrase prompt on connect — no need to
        # remember `systemd-tty-ask-password-agent --query`.
        extraOptions = {
          RemoteCommand = "systemd-tty-ask-password-agent --query";
          RequestTTY = "yes";
        };
      };
      "hannibal" = {
        hostname = "10.10.10.11";
        user = "ucorne";
        forwardAgent = true;
      };
      "pikvm-atilla" = {
        hostname = "10.10.10.12";
        user = "root";
      };
      "tornyol" = {
        hostname = "tornyol-rtx-9";
        user = "ulysse";
      };
      "shark" = {
        hostname = "roughshark.ics.cs.cmu.edu";
        user = "ucorne";
        extraOptions = {
          GSSAPIAuthentication = "yes";
          GSSAPIDelegateCredentials = "yes";
        };
      };
    };
  };

  # ── Home Manager ────────────────────────────────────────────────────
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
}
