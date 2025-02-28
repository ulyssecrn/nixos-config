{ config, pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    extensions = [
      pkgs.vscode-extensions.enkia.tokyo-night
      pkgs.vscode-extensions.ms-python.python
      pkgs.vscode-extensions.continue.continue
      pkgs.vscode-extensions.jnoortheen.nix-ide
    ];
    userSettings = {
          "window.titleBarStyle" = "custom";
          "explorer.confirmDelete" = false;
          "workbench.colorTheme" = "Tokyo Night";
           "editor.fontFamily" = "Hack Nerd Font";
    };
  };
}