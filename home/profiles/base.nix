{ config, pkgs, ... }:

{
  # ── Imports ─────────────────────────────────────────────────────────
  imports = [
    ../modules/shell.nix
    ../modules/neovim.nix
    ../modules/btop.nix
    ../modules/opencode.nix
    ../modules/claude-code.nix
    ../modules/codex.nix
    ../modules/skills
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
    gh

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
      "shell.nix"
      ".direnv"
      ".pio"
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

    enableDefaultConfig = false;

    settings = {
      "pikvm-genghis" = {
        HostName = "10.10.10.8";
        User = "root";
      };
      "genghis" = {
        HostName = "10.10.10.9";
        User = "ucorne";
        ForwardAgent = true;
        # `herdr --remote genghis` holds a long-lived SSH connection that is
        # idle whenever an agent is thinking. herdr only injects its own
        # keepalive as a *fallback* — the `*` block below sets
        # ServerAliveInterval 0 explicitly, and an explicit value wins, so
        # without this the attach silently dies to NAT/idle timeouts.
        ServerAliveInterval = 30;
      };
      "genghis-realtek" = {
        HostName = "10.10.10.7";
        User = "ucorne";
        ForwardAgent = true;
      };
      "genghis-initrd" = {
        HostName = "10.10.10.9";
        Port = 2222;
        User = "root";
        UserKnownHostsFile = "~/.ssh/known_hosts_initrd";
        RemoteCommand = "systemd-tty-ask-password-agent --query";
        RequestTTY = "yes";
      };
      "atilla" = {
        HostName = "10.10.10.10";
        User = "ucorne";
        ForwardAgent = true;
        ServerAliveInterval = 30;   # `herdr --remote atilla` — see genghis above
      };
      "atilla-initrd" = {
        HostName = "10.10.10.10";
        Port = 2222;
        User = "root";
        # Separate known_hosts: initrd has a different host key than the
        # post-boot sshd, so without this the client would yell about a
        # changed key every reboot.
        UserKnownHostsFile = "~/.ssh/known_hosts_initrd";
        # Auto-run the LUKS passphrase prompt on connect — no need to
        # remember `systemd-tty-ask-password-agent --query`.
        RemoteCommand = "systemd-tty-ask-password-agent --query";
        RequestTTY = "yes";
      };
      "hannibal" = {
        HostName = "10.10.10.11";
        User = "ucorne";
        ForwardAgent = true;
      };
      "pikvm-atilla" = {
        HostName = "10.10.10.12";
        User = "root";
      };
      "tornyol" = {
        HostName = "tornyol-rtx-9";
        User = "ulysse";
      };
      "shark" = {
        HostName = "roughshark.ics.cs.cmu.edu";
        User = "ucorne";
        GSSAPIAuthentication = "yes";
        GSSAPIDelegateCredentials = "yes";
      };
      "us-vps" = {
        HostName = "100.105.115.86";
        User = "ucorne";
      };
      "ch-vps" = {
        HostName = "100.90.226.64";
        User = "debian";
      };
      "mm-aw2" = {
        HostName = "128.2.48.10";
        User = "metamobility2";
      };
      "mm-aw3" = {
        HostName = "128.2.48.9";
        User = "metamobility3";
      };
      "mm-jetson" = {
        HostName = "172.26.193.224";
        User = "metamobility2";
      };
      "mm-exo-v3" = {
        HostName = "172.26.199.184";
        User = "exov3";
      };
      "*" = {
        ForwardAgent = false;
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
        AddKeysToAgent = "no";
        HashKnownHosts = "no";
      };
    };
  };

  # ── Home Manager ────────────────────────────────────────────────────
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
}
