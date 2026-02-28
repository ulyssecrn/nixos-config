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
    profiles = {
      default = {
        extensions = [
          pkgs.vscode-extensions.enkia.tokyo-night
          pkgs.vscode-extensions.ms-python.python
          pkgs.vscode-extensions.ms-toolsai.jupyter
          pkgs.vscode-extensions.ms-vscode.cpptools
          pkgs.vscode-extensions.llvm-vs-code-extensions.vscode-clangd
          pkgs.vscode-extensions.jnoortheen.nix-ide
          pkgs.vscode-extensions.mkhl.direnv
          pkgs.vscode-extensions.github.copilot
          pkgs.vscode-extensions.github.copilot-chat
          pkgs.vscode-extensions.james-yu.latex-workshop
        ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "sftp";
            publisher = "natizyskunk";
            version = "1.16.3";
            sha256 = "HifPiHIbgsfTldIeN9HaVKGk/ujaZbjHMiLAza/o6J4=";
          }
        ];
        userSettings = {
          "window.titleBarStyle" = "custom";
          "explorer.confirmDelete" = false;
          "workbench.colorTheme" = "Tokyo Night";
          "editor.fontFamily" = "Hack Nerd Font";
          "editor.fontSize" = 13;
          "git.confirmSync" = false;
          "github.copilot.enable" = {
            "*" = false;
          };
          "github.copilot.nextEditSuggestions.enabled" = false;
          "github.copilot.chat.byok.ollamaEndpoint" = "http://10.10.10.12:11434";
          "C_Cpp.intelliSenseEngine" = "disabled";
          "jupyter.askForKernelRestart" = false;
        };
      };
    };
  };

  stylix.targets.vscode.enable = false;

  home.packages = with pkgs; [
    antigravity
    code-cursor
  ];
}