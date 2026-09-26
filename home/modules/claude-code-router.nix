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

  # `/model <alias>` → full OpenRouter id, via the custom router below. Aliases
  # are unversioned on purpose so a model bump doesn't change muscle memory.
  # Avoid Claude Code's own aliases (opus, sonnet, haiku, fable, default).
  # `/model openrouter,<any id>` still works for anything unlisted; ccr only
  # validates the provider.
  models = {
    glm            = { id = "z-ai/glm-5.3";                  name = "GLM 5.3"; };
    glm-flash      = { id = "z-ai/glm-5.3-flash";            name = "GLM 5.3 Flash"; };
    kimi           = { id = "moonshotai/kimi-k3";            name = "Kimi K3"; };
    deepseek       = { id = "deepseek/deepseek-v4-pro-0813"; name = "DeepSeek V4 Pro"; };
    deepseek-flash = { id = "deepseek/deepseek-v4.1-flash";  name = "DeepSeek V4.1 Flash"; };
    qwen           = { id = "qwen/qwen3.8-max-0902";         name = "Qwen3.8 Max"; };
    mimo           = { id = "xiaomi/mimo-v2.6-pro";          name = "MiMo V2.6 Pro"; };
    bunny          = { id = "stealth/space-bunny-alpha";     name = "Space Bunny Alpha"; };
  };
  default = "glm";
  route = alias: "openrouter,${models.${alias}.id}";
  aliases = lib.mapAttrs (_: m: m.id) models;

  # Runs before ccr's built-in routing; returning null falls through to it.
  customRouter = pkgs.writeText "ccr-router.js" ''
    const aliases = ${builtins.toJSON aliases};
    module.exports = async (req) => {
      const id = aliases[req.body.model];
      return id ? "openrouter," + id : null;
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
      models = builtins.attrValues aliases;
      # A per-model entry is merged after the provider one, so it wins.
      transformer = {
        use = [ (openrouter "high") ];
        "${models.glm-flash.id}".use = [ (openrouter "low") ];
      };
    }];

    # Empty slots fall back to default. longContext is unset on purpose: every
    # model above is ~1M, so there's nothing bigger to escalate to.
    Router = {
      default = route default;
      background = route "glm-flash";
      image = route "mimo";
    };
    # Without this, a turn whose latest message holds an image is answered by
    # the image model outright. With it, images become placeholders and the
    # main model calls an analyzeImage tool backed by Router.image, so the
    # default model stays the one talking.
    forceUseImageAgent = true;
    CUSTOM_ROUTER_PATH = "${customRouter}";
  };

  mcpConfig = json.generate "ccr-mcp.json" {
    mcpServers.searxng = {
      command = "${pkgs.mcp-searxng}/bin/mcp-searxng";
      env.SEARXNG_URL = "http://searxng.corne.sh";
    };
  };

  # Sets the env `ccr activate` prints instead of going through `ccr code`,
  # which re-parses argv with minimist and drops positional args (the prompt).
  # Built-in WebSearch runs server-side at Anthropic, so it's swapped for
  # SearXNG over MCP. Our flags go after "$@": both are variadic and would
  # swallow a trailing prompt.
  clr = pkgs.writeShellScriptBin "clr" ''
    export ANTHROPIC_BASE_URL=${baseUrl}
    export ANTHROPIC_AUTH_TOKEN=ccr
    export NO_PROXY=127.0.0.1
    export DISABLE_TELEMETRY=true DISABLE_COST_WARNINGS=true API_TIMEOUT_MS=600000
    # Claude Code sizes auto-compact from the model it thinks it's running
    # (Opus), not the routed one.
    export CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000
    exec claude "$@" --mcp-config ${mcpConfig} --disallowedTools WebSearch
  '';
in
{
  home.packages = [ pkgs.claude-code-router clr ];

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
