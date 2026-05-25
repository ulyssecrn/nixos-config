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

  # opencode pointed at genghis's llama.cpp (OpenAI-compat at :8080/v1).
  # The model id comes from `curl http://genghis:8080/v1/models`.
  programs.opencode = {
    enable = true;
    settings = {
      "$schema" = "https://opencode.ai/config.json";
      provider.llamacpp = {
        npm = "@ai-sdk/openai-compatible";
        name = "llama.cpp (genghis)";
        options = {
          baseURL = "http://genghis:8080/v1";
          apiKey = "sk-no-key-needed";
        };
        models."Qwen3.6-27B-Q4_K_M.gguf" = {
          name = "Qwen3.6-27B";
        };
      };
      model = "llamacpp/Qwen3.6-27B-Q4_K_M.gguf";
    };
    tui = {
      theme = "tokyonight";
    };
  };

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
      "pikvm-genghis" = {
        hostname = "10.10.10.8";
        user = "root";
      };
      "genghis" = {
        hostname = "10.10.10.9";
        user = "ucorne";
        forwardAgent = true;
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
