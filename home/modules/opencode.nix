# opencode pointed at genghis's llama.cpp (OpenAI-compatible at :8080/v1).
# Imported fleet-wide via home/profiles/base.nix. The tui.theme is set by the
# Stylix opencode target (home/modules/stylix.nix) on hosts that have Stylix;
# hannibal (stable HM — no Stylix and no programs.opencode.tui option) just runs
# opencode with its default theme. Deliberately sets no `tui` here so the module
# stays valid on stable home-manager. Model id from `curl genghis:8080/v1/models`.
{ config, pkgs, ... }:

{
  programs.opencode = {
    enable = true;
    settings = {
      "$schema" = "https://opencode.ai/config.json";
      provider.llamacpp = {
        npm = "@ai-sdk/openai-compatible";
        name = "llama.cpp (genghis)";
        options = {
          baseURL = "http://genghis:8080/v1";
          apiKey = "sk-no-key-needed";
        };
        models."Qwen3.6-27B-Q4_K_M.gguf" = {
          name = "Qwen3.6-27B";
        };
      };
      model = "llamacpp/Qwen3.6-27B-Q4_K_M.gguf";
    };
  };
}
