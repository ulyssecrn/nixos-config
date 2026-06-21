# Desktop-only Stylix layer: GUI targets, fonts, wallpaper, cursor and the KDE
# kdeglobals shim. The palette + TUI core lives in home/modules/stylix.nix
# (imported fleet-wide via home/profiles/base.nix); this module only adds the
# bits that need a graphical session, so it's imported only from desktop.nix.
{ config, pkgs, ... }:

{
  stylix = {
    image = ../../wallpapers/hong-kong2.jpg;

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
