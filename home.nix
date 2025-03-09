{ config, pkgs, ... }:

{
  home.username = "ucorne";
  home.homeDirectory = "/home/ucorne";

  home.packages = with pkgs; [
    pkgs.fastfetch
    kdePackages.dolphin
    kdePackages.qtwayland
    kdePackages.okular
    kdePackages.qtsvg
    kdePackages.kio-fuse #to mount remote filesystems via FUSE
    kdePackages.kio-extras #extra protocols support (sftp, fish and more)
    kdePackages.dolphin-plugins
    kdePackages.kompare
    kdePackages.kdegraphics-thumbnailers

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
    pkgs.playerctl
    pavucontrol
    pkgs.hypridle
    wl-clipboard
    pkgs.prusa-slicer
    vesktop
    gimp
  ];

  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./kitty.nix
    ./neovim.nix
    ./vscodium.nix
    ./rofi.nix
  ];

  programs.git = {
    enable = true;
    userName = "Ulysse Corne";
    userEmail = "ulysse@corne.sh";
  };

  programs.zsh = {
    enable = true;
    shellAliases = {
      update = "sudo nixos-rebuild switch";
      codium = "codium --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host *
          IdentityAgent ~/.1password/agent.sock
    '';
  };

  fonts.fontconfig.enable = true;

  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}

