{ config, pkgs, lib, ... }:

{
  # ── Imports ─────────────────────────────────────────────────────────
  imports = [
    ../modules/hyprland.nix
    ../modules/hyprlock.nix
    ../modules/stylix.nix
    ../modules/theme.nix
    ../modules/kitty.nix
    ../modules/vscode.nix
    ../modules/rofi.nix
    ../modules/dunst.nix
  ];

  # ── Packages ────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # Fonts — Hack/Noto/emoji come from Stylix (font-packages target).
    noto-fonts-cjk-sans
    liberation_ttf                   # Arial/Times/Courier metric substitutes
    gyre-fonts                       # required by texlive

    # Desktop tools
    playerctl
    pavucontrol
    wl-clipboard
    libnotify
    networkmanagerapplet
    android-tools
    librepods

    # GNOME Utilities
    seahorse                         # gnome keyring manager
    gcr                              # gnome keyring prompt
    gnome-disk-utility               # disk utility
    gnome-calculator                 # calculator
    baobab                           # disk usage analyzer

    # KDE Utilities
    kdePackages.dolphin              # file manager
    kdePackages.okular               # pdf viewer
    kdePackages.gwenview             # image viewer
    kdePackages.ark                  # archive utility
    kdePackages.skanlite             # scanner utility
    kdePackages.kmines               # minesweeper
    kdePackages.kio-fuse             # for remote shares
    kdePackages.kio-extras           # more protocols sftp etc
    kdePackages.qtsvg                # dolphin svg icon support
    kdePackages.kded                 # daemon
    libsForQt5.qt5ct                 # qt5 theming
    kdePackages.qt6ct                # qt6 theming
    libsForQt5.qtstyleplugin-kvantum # theme engine
    kdePackages.plasma-workspace

    # Utilities
    brave
    obsidian
    nextcloud-client
    libreoffice
    vlc
    pdfchain                         # pdf merger
    veracrypt
    obs-studio
    calibre

    # Images / Photography
    gimp
    darktable
    exiftool
    digikam

    # LaTeX
    texliveFull
    pandoc

    # Gaming
    vesktop                          # discord
    ryubing
    prismlauncher                    # minecraft
    mangohud

    # 3D printing / CAD
    prusa-slicer
    freecad
    openscad
    kicad
  ];

  # ── opencode ────────────────────────────────────────────────────────
  # Points at genghis's llama.cpp (OpenAI-compat at :8080/v1). Lives in the
  # desktop profile (not base) because `programs.opencode.tui` is only in
  # newer home-manager; the Pi (hannibal) is on stable and doesn't ship it.
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
    # tui.theme comes from Stylix (targets.opencode → generated "stylix" theme).
  };

  # ── Bitwarden SSH agent ─────────────────────────────────────────────
  # Use Bitwarden's agent at the local desktop, but step aside when reached
  # via SSH so the forwarded agent (from the client) takes over. Otherwise
  # `git pull` on this host hits the locked local Bitwarden socket and fails.
  programs.ssh.matchBlocks."*".extraOptions.IdentityAgent = "SSH_AUTH_SOCK";
  programs.zsh.initContent = lib.mkBefore ''
    if [ -z "$SSH_CONNECTION" ]; then
      export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
    fi
  '';

  # ── XDG MIME apps associations ──────────────────────────────────────
  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory" = ["org.kde.dolphin.desktop"]; # Directories
        # Archive files
        "application/zip" = ["org.kde.ark.desktop"]; # .zip
        "application/x-7z-compressed" = ["org.kde.ark.desktop"]; # .7z
        "application/x-rar" = ["org.kde.ark.desktop"]; # .rar
        "application/x-tar" = ["org.kde.ark.desktop"]; # .tar
        "application/gzip" = ["org.kde.ark.desktop"]; # .gz
        "application/x-xz" = ["org.kde.ark.desktop"]; # .xz
        # Document files
        "text/*" = ["code.desktop"];
        "text/plain" = ["code.desktop"];
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = ["writer.desktop"]; # .docx
        "application/vnd.openxmlformats-officedocument.presentationml.presentation" = ["impress.desktop"]; # .pptx
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = ["calc.desktop"]; # .xlsx
        "application/msword" = ["writer.desktop"]; # .doc
        "application/vnd.ms-powerpoint" = ["impress.desktop"]; # .ppt
        "application/vnd.ms-excel" = ["calc.desktop"]; # .xls
        "application/pdf" = ["org.kde.okular.desktop"];
        # Media files
        "audio/*" = ["vlc.desktop"];
        "video/*" = ["vlc.desktop"];
        "image/*" = ["org.kde.gwenview.desktop"];
        "image/png" = ["org.kde.gwenview.desktop"];
        "image/jpeg" = ["org.kde.gwenview.desktop"];
        # Links
        "x-scheme-handler/https" = ["brave-browser.desktop"];
        "x-scheme-handler/http" = ["brave-browser.desktop"];
        "x-scheme-handler/mailto" = ["brave-browser.desktop"];
      };
    };
  };

  # ── Fonts ───────────────────────────────────────────────────────────
  # defaultFonts are written by Stylix (fontconfig target); only keep enable.
  fonts.fontconfig.enable = true;
}
