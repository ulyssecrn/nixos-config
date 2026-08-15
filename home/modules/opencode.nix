# opencode pointed at genghis's llama.cpp (OpenAI-compatible at :8080/v1).
# Imported fleet-wide via home/profiles/base.nix. The tui.theme is set by the
# Stylix opencode target (home/modules/stylix.nix) on hosts that have Stylix;
# hannibal (stable HM — no Stylix and no programs.opencode.tui option) just runs
# opencode with its default theme. Deliberately sets no `tui` here so the module
# stays valid on stable home-manager. Model id from `curl genghis:8080/v1/models`.
{ config, pkgs, ... }:

let
  mcp-searxng = pkgs.buildNpmPackage rec {
    pname = "mcp-searxng";
    version = "1.8.0";
    src = pkgs.fetchFromGitHub {
      owner = "ihor-sokoliuk";
      repo = "mcp-searxng";
      rev = "v${version}";
      sha256 = "sha256-xyNjBJ268JqJVhKOC/wLQ4SqKqTI+TgQEgbSdYLGid0=";
    };
    npmDepsHash = "sha256-dVFX5wmYTd28e9FsmwkuuF09do9Z8+Du9osxAFEx4/4=";
  };
in
{
  home.packages = [ mcp-searxng ];

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
        models."Qwen3.8-27B-Q4_K_M.gguf" = {
          name = "Qwen3.8-27B";
        };
      };
      model = "llamacpp/Qwen3.8-27B-Q4_K_M.gguf";
      mcp = {
        searxng = {
          type = "local";
          command = [ "${mcp-searxng}/bin/mcp-searxng" ];
         environment = {
            SEARXNG_URL = "http://searxng.corne.sh";
          };
        };
      };
    };
  };
}
