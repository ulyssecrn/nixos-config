{ config, pkgs, ... }:

{
  # ── Imports ─────────────────────────────────────────────────────────
    imports = [
    ./modules/hyprland.nix
    ./modules/hyprlock.nix
    ./modules/theme.nix
    ./modules/kitty.nix
    ./modules/neovim.nix
    ./modules/vscode.nix
    ./modules/rofi.nix
    ./modules/dunst.nix
    ./modules/shell.nix
    ./modules/btop.nix
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

    # Fonts
    nerd-fonts.hack
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
    liberation_ttf
    dejavu_fonts
    freefont_ttf
    gyre-fonts
    unifont
    ubuntu-classic

    # Desktop tools
    playerctl
    pavucontrol
    wl-clipboard
    libnotify
    networkmanagerapplet

    # GNOME Utilities
    dconf                            # config utility
    adwaita-icon-theme               # default icon theme
    nautilus                         # file manager
    loupe                            # image viewer
    evince                           # pdf viewer
    seahorse                         # gnome keyring manager
    simple-scan                      # scanner utility
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

    # Utilities
    brave
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
    blender
  ];

  # ── Git ─────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings.user = {
      name = "Ulysse Corne";
      email = "ulysse@corne.sh";
    };
    ignores = [
      ".venv"
      ".envrc"
      ".vscode"
    ];
  };

  # ── SSH ─────────────────────────────────────────────────────────────
  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host genghis
          HostName 10.10.10.12
          User ucorne
      Host atilla
          HostName 10.10.10.10
          User root
      Host loki-pi
          HostName 10.10.10.11
          User pi
      Host *
          IdentityAgent ~/.bitwarden-ssh-agent.sock
    '';
  };

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
  fonts.fontconfig.enable = true;

  # ── Home Manager ────────────────────────────────────────────────────
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
}

