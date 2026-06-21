# Stylix is the single source of truth for the Tokyo Night palette, fonts,
# wallpaper and cursor across desktop hosts (loki, odin). Targets are opt-in
# (autoEnable = false) so nothing gets themed behind our back — custom-layout
# configs (waybar, rofi, hyprlock) keep their own styling and pull colours
# from config.lib.stylix.colors inline.
{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.stylix.homeModules.stylix ];

  stylix = {
    enable = true;
    polarity = "dark";
    image = ../../wallpapers/hong-kong2.jpg;
    # Genuine Tokyo Night values (from the old hand-set kitty palette) rather
    # than the base16 `tokyo-night-dark.yaml` approximation — keeps the terminal
    # ANSI colours faithful. Everything (kitty, gtk, qt, waybar…) derives from here.
    base16Scheme = {
      base00 = "1a1b26"; # bg
      base01 = "16161e"; # darker bg / panels
      base02 = "283457"; # selection
      base03 = "414868"; # comments / bright black
      base04 = "545c7e";
      base05 = "c0caf5"; # fg
      base06 = "a9b1d6";
      base07 = "c0caf5";
      base08 = "f7768e"; # red
      base09 = "ff9e64"; # orange
      base0A = "e0af68"; # yellow
      base0B = "9ece6a"; # green
      base0C = "7dcfff"; # cyan
      base0D = "7aa2f7"; # blue
      base0E = "bb9af7"; # magenta
      base0F = "db4b4b";
    };
    autoEnable = false;

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };

    fonts = {
      monospace = { package = pkgs.nerd-fonts.hack; name = "Hack Nerd Font"; };
      sansSerif = { package = pkgs.noto-fonts; name = "Noto Sans"; };
      serif     = { package = pkgs.noto-fonts; name = "Noto Serif"; };
      emoji     = { package = pkgs.noto-fonts-color-emoji; name = "Noto Color Emoji"; };
      sizes.terminal = 10;
    };

    targets = {
      kitty.enable = true;
      gtk.enable = true;
      qt.enable = true;
      dunst.enable = true;
      vscode.enable = true;            # generates the "Stylix" colour theme + fonts
      # Stylix owns the wallpaper — drives services.hyprpaper from stylix.image.
      hyprpaper.enable = true;
      # Stylix owns fonts — installs the font packages and writes
      # fonts.fontconfig.defaultFonts (at mkOrder priority, still overridable).
      font-packages.enable = true;
      fontconfig.enable = true;
      # Stage 2 — these keep custom layouts, colours interpolated by hand.
      waybar.enable = false;
      rofi.enable = false;
      hyprlock.enable = false;
    };
  };

  gtk.enable = true;

  # KDE-framework apps (Dolphin, Okular, Gwenview…) run on Hyprland without
  # Plasma, so they read kdeglobals. Themed via Kvantum (Stylix's
  # Base16Kvantum). Three non-obvious bits:
  #   widgetStyle=kvantum             — use the Kvantum theme for widgets
  #   [UiSettings] ColorScheme=*      — defer to Kvantum's colours, not a default scheme
  #   [Colors:View] BackgroundNormal=#00000000 — transparent item-view bg so
  #     file lists show Kvantum's dark background instead of defaulting to white
  xdg.configFile."kdeglobals".text = ''
    [General]
    TerminalApplication=kitty

    [Colors:View]
    BackgroundNormal=#00000000

    [KDE]
    widgetStyle=kvantum

    [UiSettings]
    ColorScheme=*
  '';
}
