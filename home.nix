{ config, pkgs, ... }:

{
  home.username = "ucorne";
  home.homeDirectory = "/home/ucorne";

  home.packages = with pkgs; [
    pkgs.fastfetch

    nautilus
    loupe
    evince
    seahorse
    d-spy
    dconf
    xdg-utils
    adwaita-icon-theme

    nnn # terminal file manager

    zip
    xz
    unzip
    p7zip

    eza # A modern replacement for ‘ls’

    nmap # A utility for network discovery and security auditing

    which
    tree
    gnutar
    gawk

    btop  # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    sysstat
    lm_sensors # for `sensors` command
    usbutils # lsusb

    pkgs.nerd-fonts.hack
    pkgs.hyprpolkitagent
    pkgs.hyprpicker
    pkgs.playerctl
    pavucontrol
    pkgs.hypridle
    wl-clipboard
    pkgs.prusa-slicer
    vesktop
    gimp
    nextcloud-client

    noto-fonts
    noto-fonts-emoji
    noto-fonts-cjk-sans
    liberation_ttf
    dejavu_fonts
    freefont_ttf
    gyre-fonts
    unifont
    ubuntu_font_family

    simple-scan
    gnome-disk-utility

    godot

    hyprshot
    yt-dlp
    vlc
    obs-studio
    libreoffice

    killall
    libnotify
    baobab
    gnome-calculator
    bitwarden

    brave

    ryubing
  ];

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
    userName = "Ulysse Corne";
    userEmail = "ulysse@corne.sh";
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
    };
    zplug = {
      enable = true;
      plugins = [
        { name = "zsh-users/zsh-autosuggestions"; }
        { name = "zsh-users/zsh-syntax-highlighting"; }
        { name = "marlonrichert/zsh-autocomplete"; }
      ];
    };
    initContent = ''
    eval "$(uv generate-shell-completion zsh)"
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

