{ config, pkgs, ... }:

{
  home.username = "ucorne";
  home.homeDirectory = "/home/ucorne";

  home.packages = with pkgs; [
    # CLI tools
    eza # ls replacement
    nnn # terminal file manager
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
    btop
    lm_sensors # sensors
    usbutils # lsusb

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

    # GNOME Utilities
    dconf # config utility
    adwaita-icon-theme # default icon theme
    nautilus # file manager
    loupe # image viewer
    evince # pdf viewer
    seahorse # gnome keyring manager
    simple-scan
    gnome-disk-utility
    gnome-calculator
    baobab # disk usage analyzer 

    # KDE Utilities
    kdePackages.dolphin # file manager
    kdePackages.okular # pdf
    kdePackages.gwenview # image
    kdePackages.ark # archive utility
    kdePackages.skanlite # scanning
    kdePackages.kmines # minesweeper
    kdePackages.kio-fuse # for remote shares
    kdePackages.kio-extras # more protocols sftp etc
    kdePackages.qtsvg # dolphin svg icon support
    kdePackages.kded # daemon
    libsForQt5.qt5ct # qt5 theming
    kdePackages.qt6ct # qt6 theming
    libsForQt5.qtstyleplugin-kvantum # theme engine

    # Utilities
    brave
    bitwarden-desktop
    nextcloud-client
    libreoffice
    vlc
    gimp
    darktable
    exiftool
    digikam
    veracrypt
    obs-studio
    godot # game engine
    calibre
    koreader
    pdfchain
    texliveFull
    pandoc

    # Gaming
    vesktop # discord
    ryubing
    prismlauncher
    mangohud

    # 3D printing / CAD
    prusa-slicer
    openscad
    blender
  ];

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

  imports = [
    ./hyprland.nix
    ./kitty.nix
    ./neovim.nix
    ./vscode.nix
    ./rofi.nix
    ./dunst.nix
  ];

  programs.git = {
    enable = true;
    settings.user = {
      name = "Ulysse Corne";
      email = "ulysse@corne.sh";
    };
    ignores = [
      ".venv"
      ".envrc"
    ];
  };

  programs.zsh = {
    enable = true;
    shellAliases = {
      upgrade = "sudo nixos-rebuild switch";
      update = "cd /home/ucorne/.nixos && nix flake update";
      clf = "clear";
      ls = "exa --group-directories-first --icons --git";
      ll = "exa -l --group-directories-first --icons --git";
      la = "exa -la --group-directories-first --icons --git";
      open = "xdg-open";
      ff = "fastfetch";
      cl = "function _cl() { clang -std=c2x -Wall -lm -o \"\${1%.c}\" \"\$1\"; }; _cl";
    };
    zplug = {
      enable = true;
      plugins = [
        { name = "zsh-users/zsh-autosuggestions"; }
        { name = "zsh-users/zsh-syntax-highlighting"; }
        { name = "marlonrichert/zsh-autocomplete"; }
        { name = "chisui/zsh-nix-shell"; }
        { name = "ptavares/zsh-direnv"; }
      ];
    };
    initContent = ''
    eval "$(uv generate-shell-completion zsh)"
    export PATH="/home/ucorne/.local/bin:$PATH"
    '';
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host genghis
          HostName 10.10.10.12
          User ucorne
      Host atilla
          HostName 10.10.10.10
          User root
      Host loki
          HostName 10.10.10.11
          User pi
      Host *
          IdentityAgent ~/.bitwarden-ssh-agent.sock
    '';
  };

  fonts.fontconfig.enable = true;

  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}

