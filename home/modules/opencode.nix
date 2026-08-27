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
        models."Qwen3.8-27B-UD-IQ4_XS.gguf" = {
          name = "Qwen3.8-27B";
          # BOTH fields are REQUIRED, for different reasons — opencode does
          # not read either from an openai-compatible provider's /models
          # endpoint (upstream #40908, still open).
          #
          # `context` unset => usable window computes to 0 and the guard
          #   `if (limit.context === 0) return false` disables auto-compaction
          #   outright; sessions then grow until llama.cpp rejects them with
          #   "exceeds the available context size" (upstream #45368).
          #   Before ~1.17 there was no such guard, so usable=0 meant
          #   `tokens >= 0` was always true and it compacted after EVERY
          #   response instead (#31152, the infinite Build→Compaction loop).
          #   Same missing field, opposite symptom — don't let "it used to
          #   compact" suggest the limit was ever being read.
          # `output` unset => maxOutputTokens() falls back to a flat 32k, and
          #   usable = context - 32000. Harmless on a window this size, fatal
          #   on a small one (#45368 measured 30 compactions in 15 min on a
          #   16k window).
          #
          # Trigger is `usable = context - maxOutputTokens`, so this compacts
          # at ~176,808 tokens. Keep `context` in sync with ctx-size in
          # hosts/genghis/configuration.nix minus headroom: the server
          # allocates 200704, measured fill ceiling ~187,934.
          limit = {
            context = 185000;
            output = 8192;
          };
        };
      };
      model = "llamacpp/Qwen3.8-27B-UD-IQ4_XS.gguf";
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
