{ config, pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    #package = (pkgs.vscode.override{ isInsiders = true; }).overrideAttrs (oldAttrs: rec {
    #  src = (builtins.fetchTarball {
    #    url = "https://code.visualstudio.com/sha/download?build=insider&os=linux-arm64";
    #    sha256 = "0qcj6ipzxmbb9w4c3d4pj83bjqbls0g2k21zh2wjx5707zxwr1n8";
    #  });
    #  version = "latest";
    #});
    extensions = [
      pkgs.vscode-extensions.enkia.tokyo-night
      pkgs.vscode-extensions.ms-python.python
      pkgs.vscode-extensions.jnoortheen.nix-ide
    ];
    userSettings = {
          "window.titleBarStyle" = "custom";
          "explorer.confirmDelete" = false;
          "workbench.colorTheme" = "Tokyo Night";
          "editor.fontFamily" = "Hack Nerd Font";
          "git.confirmSync" = false;
    };
  };
}