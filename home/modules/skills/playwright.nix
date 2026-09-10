# Playwright CLI + the agent skill that drives it — for all three agents, not
# just Claude Code. Unlike the pure-markdown packs in ./default.nix this is a
# *built* npm binary the skill is inseparable from (the SKILL.md ships inside the
# package tarball and is useless without the `playwright` binary on PATH), so it
# stays pinned in home/pkgs/playwright-cli.nix and bumps only when you raise its
# version + hashes — a flake input can't auto-bump a built package's npmDepsHash.
#
# Deliberately NOT fleet-wide via base.nix, for two reasons:
#  1. On stable home-manager `programs.claude-code.skills.<name>` pointing at a
#     store path is an import-from-derivation — release-26.05's module calls
#     `lib.pathIsDirectory` on the value, realising the derivation during
#     *evaluation*. Evaluating hannibal would then ask genghis to build
#     playwright-cli for aarch64, which it can't, and the flake-bot eval gate
#     dies. (HM master checks `lib.isPath` first and never stats it.)
#  2. Opt-in keeps a full chromium closure off the hosts with no use for a
#     browser.
{ pkgs, ... }:

let
  playwright-cli = pkgs.callPackage ../../pkgs/playwright-cli.nix { };
  skillDir = "${playwright-cli}/lib/node_modules/@playwright/cli/skills/playwright-cli";
in
{
  # The skill drives this binary, so it has to be on PATH.
  home.packages = [ playwright-cli ];

  # Browser automation. Upstream steers coding agents at the CLI + SKILL over
  # the MCP server (cheaper in context: no tool schemas, no accessibility-tree
  # dumps), so that's what we install. `playwright-cli install --skills` is
  # the imperative equivalent and would only write a project-local
  # ./.claude/skills — this puts it in each agent's global skills dir for every
  # repo, and pins it to the same store path as the binary.
  #
  # A directory value gets symlinked wholesale, so the skill's references/ come
  # along. The SKILL.md is agent-neutral, so the one store path feeds all three
  # (their `skills` options treat a path-like string identically). Swap to the
  # MCP server instead with:
  #   mcpServers.playwright.command = lib.getExe pkgs.playwright-mcp;
  programs.claude-code.skills.playwright-cli = skillDir;
  programs.codex.skills.playwright-cli = skillDir;
  programs.opencode.skills.playwright-cli = skillDir;
}
