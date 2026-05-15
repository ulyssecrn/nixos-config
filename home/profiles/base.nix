{ config, pkgs, ... }:

{
  # ── Imports ─────────────────────────────────────────────────────────
  imports = [
    ../modules/shell.nix
    ../modules/neovim.nix
    ../modules/btop.nix
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

    matchBlocks = {
      "genghis" = {
        hostname = "10.10.10.9";
        user = "ucorne";
      };
      "atilla" = {
        hostname = "10.10.10.10";
        user = "root";
      };
      "hannibal" = {
        hostname = "10.10.10.11";
        user = "ucorne";
      };
      "pikvm" = {
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
      "*" = {
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
    };
  };

  # ── Home Manager ────────────────────────────────────────────────────
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
}
