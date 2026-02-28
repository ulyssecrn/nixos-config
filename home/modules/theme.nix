# home/modules/theme.nix
{ config, pkgs, ... }:

let
  tokyo-night-kvantum = pkgs.fetchFromGitHub {
      owner = "lkxe";
      repo = "Kvantum-Tokyo-Night";
      rev = "b6dbdadac164d9b949602603fc317e5bce686d5d";
      sha256 = "sha256-g32cWGpMC1jRMNarE8B6qc0Lt79fJTugYTnOXqntA2k=";
    };
in
{
  # ── Cursor ──────────────────────────────────────────────────────────
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    x11.enable = true;
    gtk.enable = true;
  };

  # ── GTK theming ─────────────────────────────────────────────────────
  gtk = {
    enable = true;
    gtk3.extraConfig.gtk-decoration-layout = "menu:";
    theme = {
      name = "Tokyonight-Dark";
      package = pkgs.tokyonight-gtk-theme;
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
  };

  # ── Qt / Kvantum theming ────────────────────────────────────────────
  xdg = {
    configFile = {
      "Kvantum/TokyoNight/TokyoNight.kvconfig".source = "${tokyo-night-kvantum}/Kvantum-Tokyo-Night/Kvantum-Tokyo-Night.kvconfig";
      "Kvantum/TokyoNight/TokyoNight.svg".source = "${tokyo-night-kvantum}/Kvantum-Tokyo-Night/Kvantum-Tokyo-Night.svg";
      "Kvantum/kvantum.kvconfig".text = "[General]\ntheme=TokyoNight";
      /*
      "kdeglobals".text = ''
        [General]
        TerminalApplication=kitty

        [Colors:View]
        BackgroundNormal=#00000000

        [KDE]
        widgetStyle=kvantum

        [UiSettings]
        ColorScheme=*
        '';
    */
    };
  };
}