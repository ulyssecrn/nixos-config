{ config, pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles = {
      default = {
        extensions = [
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
          # Colour theme + editor fonts/sizes come from Stylix (targets.vscode).
          "window.titleBarStyle" = "custom";
          "explorer.confirmDelete" = false;
          "git.confirmSync" = false;
          "github.copilot.enable" = {
            "*" = false;
          };
          "github.copilot.nextEditSuggestions.enabled" = false;
          "C_Cpp.intelliSenseEngine" = "disabled";
          "jupyter.askForKernelRestart" = false;
        };
      };
    };
  };
  # Copilot Chat BYOK — register genghis's llama.cpp (OpenAI-compatible at
  # :8080/v1) as a "Custom Endpoint" model. Modern BYOK lives in
  # chatLanguageModels.json, not settings.json. apiKey is a throwaway since
  # llama.cpp doesn't authenticate; `genghis` resolves via /etc/hosts.
  # force: VS Code writes this file itself, so HM must take ownership of it.
  home.file.".config/Code/User/chatLanguageModels.json".force = true;
  home.file.".config/Code/User/chatLanguageModels.json".text = builtins.toJSON [
    {
      name = "llama.cpp (genghis)";
      vendor = "customendpoint";
      apiType = "chat-completions";
      apiKey = "sk-no-key-needed";
      models = [
        {
          id = "Qwen3.6-27B-Q4_K_M.gguf";
          name = "Qwen3.6-27B (genghis)";
          url = "http://genghis:8080/v1/chat/completions";
          toolCalling = true;
          vision = true;            # served with mmproj-F16
          maxInputTokens = 138000;  # fillable ceiling per club-3090 bench
          maxOutputTokens = 8192;
        }
      ];
    }
  ];

  home.packages = with pkgs; [
    antigravity
    code-cursor
  ];
}
