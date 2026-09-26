# claude-code-router (`ccr`) — local proxy that serves the Anthropic API to
# claude-code and forwards to OpenRouter. The nix-set claude-code model
# (claude-opus-5-5) is only a label here: ccr swaps it for Router.default, and
# the haiku-named side calls for Router.background. `/model provider,model`
# bypasses routing for the session.
#
# The key stays out of the store: ccr expands `$VAR` in config values from its
# own environment, which the service loads from an env file. Bootstrap:
#   ccr stop    # a hand-started instance holds :3456 and the pid file
#   mv ~/.claude-code-router/config.json{,.old}   # HM won't clobber a real file
#   install -m600 /dev/null ~/.claude-code-router/env
#   echo 'OPENROUTER_API_KEY=sk-or-...' > ~/.claude-code-router/env
#
# config.json is a read-only store symlink, so the web UI (`ccr ui`) can't save.
# Restart with `systemctl --user restart claude-code-router`, never `ccr
# restart`: that kills the unit's process and respawns a detached copy outside
# systemd.
{ lib, pkgs, ... }:

let
  json = pkgs.formats.json { };
  port = 3456;
  baseUrl = "http://127.0.0.1:${toString port}";

  # `/model <alias>` → provider + model id, via the custom router below. Aliases
  # are unversioned on purpose so a model bump doesn't change muscle memory.
  # Avoid Claude Code's own aliases (opus, sonnet, haiku, fable, default).
  # `/model openrouter,<any id>` still works for anything unlisted; ccr only
  # validates the provider. `vision` = accepts image input (OpenRouter's
  # input_modalities; genghis serves the Qwen projector).
  models = lib.mapAttrs (_: m: { provider = "openrouter"; } // m) {
    glm            = { id = "z-ai/glm-5.3";                  name = "GLM 5.3"; };
    glm-flash      = { id = "z-ai/glm-5.3-flash";            name = "GLM 5.3 Flash";       vision = true; };
    kimi           = { id = "moonshotai/kimi-k3";            name = "Kimi K3";             vision = true; };
    deepseek       = { id = "deepseek/deepseek-v4-pro-0813"; name = "DeepSeek V4 Pro"; };
    deepseek-flash = { id = "deepseek/deepseek-v4.1-flash";  name = "DeepSeek V4.1 Flash"; vision = true; };
    mimo           = { id = "xiaomi/mimo-v2.6-pro";          name = "MiMo V2.6 Pro";       vision = true; };
    # Unversioned aliases: whatever genghis serves. llama.cpp ignores the model
    # field (single model), so ids are free labels — which is what lets two
    # aliases carry different per-model transformer settings to one model.
    qwen = {
      provider = "genghis";
      id = "qwen3.8-27b";
      name = "Qwen3.8 27B (genghis)";
      vision = true;
    };
    qwen-medium = {
      provider = "genghis";
      id = "qwen3.8-27b-medium";
      name = "Qwen3.8 27B medium (genghis)";
      vision = true;
    };
  };
  default = "glm";
  route = alias: "${models.${alias}.provider},${models.${alias}.id}";
  aliases = lib.mapAttrs (_: m: m.id) models;
  idsFor = provider: map (m: m.id) (lib.filter (m: m.provider == provider) (builtins.attrValues models));

  # Runs before ccr's built-in routing; returning null falls through to it.
  #
  # Images are handled here, not by ccr's image agent: in ccr 2.0.0 the agent's
  # streaming path feeds raw bytes to a text SSE parser (`buffer += chunk` on a
  # Uint8Array), so every streamed image turn comes back empty. Instead: a model
  # that can see gets the image as-is; for a text-only target, the turn that
  # carries a new image goes to MiMo, and older images are swapped for a
  # placeholder so the text model can carry on from that answer.
  customRouter = pkgs.writeText "ccr-router.js" ''
    const routes = ${builtins.toJSON (lib.mapAttrs (alias: _: route alias) models)};
    const vision = new Set(${builtins.toJSON (map route (builtins.attrNames (lib.filterAttrs (_: m: m.vision or false) models)))});
    const imageRoute = ${builtins.toJSON (route "mimo")};
    const placeholder = { type: "text", text: "[Image attached here. It was viewed and is described in the assistant reply that follows; treat that description as accurate.]" };
    const isImage = (b) => b?.type === "image";
    const hasImage = (msg) => Array.isArray(msg?.content) && msg.content.some((b) =>
      isImage(b) || (b?.type === "tool_result" && Array.isArray(b.content) && b.content.some(isImage)));
    const strip = (msg) => {
      if (!Array.isArray(msg.content)) return;
      msg.content = msg.content.map((b) => {
        if (isImage(b)) return placeholder;
        if (b?.type === "tool_result" && Array.isArray(b.content)) b.content = b.content.map((c) => isImage(c) ? placeholder : c);
        return b;
      });
    };
    module.exports = async (req, config) => {
      const model = req.body.model ?? "";
      const target = routes[model] ?? null;
      const effective = target
        ?? (model.includes(",") ? model
        : model.includes("haiku") ? config.Router.background
        : config.Router.default);
      const messages = req.body.messages ?? [];
      if (vision.has(effective) || !messages.some(hasImage)) return target;
      if (hasImage(messages[messages.length - 1])) return imageRoute;
      messages.forEach(strip);
      return target;
    };
  '';

  # ccr maps Claude Code's thinking to `reasoning.enabled = (type == "enabled")`,
  # so anything else (the Opus label, `/model` ids) arrives as reasoning off:
  # Kimi silently complies, GLM 5.3 400s. The transformer's options are merged
  # over the request body, forcing it back on. require_parameters keeps
  # OpenRouter off hosts that would silently drop tools/reasoning (some Kimi K3
  # endpoints serve no tools at all).
  openrouter = effort: [ "openrouter" {
    reasoning = { enabled = true; inherit effort; };
    provider.require_parameters = true;
  } ];

  configFile = json.generate "ccr-config.json" {
    # No APIKEY: with providers configured and no key, ccr forces the bind to
    # 127.0.0.1 regardless of HOST.
    HOST = "127.0.0.1";
    PORT = port;
    API_TIMEOUT_MS = 600000;
    LOG = false;

    Providers = [{
      name = "openrouter";
      api_base_url = "https://openrouter.ai/api/v1/chat/completions";
      api_key = "$OPENROUTER_API_KEY";
      models = idsFor "openrouter";
      # A per-model entry is merged after the provider one, so it wins.
      transformer = {
        use = [ (openrouter "high") ];
        "${models.glm-flash.id}".use = [ (openrouter "low") ];
      };
    } {
      name = "genghis";
      api_base_url = "http://genghis:8080/v1/chat/completions";
      api_key = "none";
      models = idsFor "genghis";
      # Effort is pinned per alias rather than left to the server default
      # (also xhigh, see hosts/genghis/configuration.nix). customparams
      # deep-merges, and the per-model entry runs last, so qwen-medium's effort
      # wins. Claude Code's cache_control markers mean nothing to llama.cpp.
      transformer = {
        use = [
          "cleancache"
          [ "customparams" { chat_template_kwargs = { enable_thinking = true; reasoning_effort = "xhigh"; }; } ]
        ];
        "${models.qwen-medium.id}".use = [
          [ "customparams" { chat_template_kwargs.reasoning_effort = "medium"; } ]
        ];
      };
    }];

    # Empty slots fall back to default. longContext is unset on purpose: it
    # escalates by size, and the default is already the ~1M end of the range.
    Router = {
      default = route default;
      background = route "glm-flash";
    };
    CUSTOM_ROUTER_PATH = "${customRouter}";
  };

  mcpConfig = json.generate "ccr-mcp.json" {
    mcpServers.searxng = {
      command = "${pkgs.mcp-searxng}/bin/mcp-searxng";
      env.SEARXNG_URL = "http://searxng.corne.sh";
    };
  };

  # The system prompt still names WebSearch in places; without this, weaker
  # models answer from memory rather than reach for an unfamiliar MCP tool.
  searchHint = "The built-in WebSearch tool is unavailable in this session. For anything current or outside your training data, search with the searxng MCP tools (searxng_web_search, then web_url_read to read a result) instead of answering from memory.";

  # Sets the env `ccr activate` prints instead of going through `ccr code`,
  # which re-parses argv with minimist and drops positional args (the prompt).
  # Built-in WebSearch runs server-side at Anthropic, so it's swapped for
  # SearXNG over MCP. Our flags go after "$@": both are variadic and would
  # swallow a trailing prompt. CLAUDE_CODE_AUTO_COMPACT_WINDOW is needed
  # because Claude Code sizes auto-compact from the model it thinks it's
  # running (Opus), not the routed one.
  launcher = name: env: pkgs.writeShellScriptBin name ''
    export ANTHROPIC_BASE_URL=${baseUrl}
    export ANTHROPIC_AUTH_TOKEN=ccr
    export NO_PROXY=127.0.0.1
    export DISABLE_TELEMETRY=true DISABLE_COST_WARNINGS=true API_TIMEOUT_MS=600000
    ${lib.concatLines (lib.mapAttrsToList (k: v: "export ${k}=${toString v}") env)}
    exec claude "$@" --mcp-config ${mcpConfig} --disallowedTools WebSearch \
      --append-system-prompt ${lib.escapeShellArg searchHint}
  '';

  clr = launcher "clr" { CLAUDE_CODE_AUTO_COMPACT_WINDOW = 1000000; };

  # Everything on genghis, side calls and subagents included: they arrive as
  # the tier aliases (haiku for titles/Explore, sonnet/opus for some agents),
  # which ccr would otherwise send to OpenRouter. 240K matches opencode's and
  # LibreChat's cap for the same server: -c 262144, deepest shown q4_0 fill
  # 240,635 (see hosts/genghis/configuration.nix).
  clg = launcher "clg" ({
    ANTHROPIC_MODEL = "qwen";
    CLAUDE_CODE_AUTO_COMPACT_WINDOW = 240000;
    # Titles and Explore are small, frequent calls: xhigh would stall them.
    ANTHROPIC_DEFAULT_HAIKU_MODEL = "qwen-medium";
  } // lib.genAttrs
    (map (tier: "ANTHROPIC_DEFAULT_${tier}_MODEL") [ "FABLE" "OPUS" "SONNET" ])
    (_: "qwen"));
in
{
  home.packages = [ pkgs.claude-code-router clr clg ];

  home.file.".claude-code-router/config.json".source = configFile;

  # Read by claude-statusline.pl. Claude Code only knows the model it asked for
  # (the nix-set Opus), so the statusline needs the routed default and labels.
  home.file.".claude-code-router/statusline.json".source = json.generate "ccr-statusline.json" {
    inherit baseUrl aliases;
    default = models.${default}.id;
    names = lib.mapAttrs' (_: m: lib.nameValuePair m.id m.name) models;
  };

  systemd.user.services.claude-code-router = {
    Unit = {
      Description = "claude-code-router";
      X-Restart-Triggers = [ "${configFile}" ];
    };
    Service = {
      EnvironmentFile = "%h/.claude-code-router/env";
      # `ccr start` exits 0 without serving if the pid file names a live
      # process, and a stale pid from the last boot can collide.
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f %h/.claude-code-router/.claude-code-router.pid";
      ExecStart = "${pkgs.claude-code-router}/bin/ccr start";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
