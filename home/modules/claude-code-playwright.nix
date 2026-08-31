# Playwright CLI + the Claude Code skill that drives it. Deliberately NOT in
# claude-code.nix: that module is fleet-wide via home/profiles/base.nix, and on
# stable home-manager `programs.claude-code.skills.<name>` pointing at a store
# path is an import-from-derivation — release-26.05's module calls
# `lib.pathIsDirectory` on the value, which realises the derivation during
# *evaluation*. Evaluating hannibal then asks genghis to build playwright-cli
# for aarch64, which it can't, and the flake-bot eval gate dies. (HM master
# checks `lib.isPath` first and never stats it, so odin was never affected.)
#
# Keeping it opt-in also keeps a full chromium closure off the hosts that have
# no use for a browser.
{ pkgs, ... }:

let
  playwright-cli = pkgs.callPackage ../pkgs/playwright-cli.nix { };
in
{
  # The skill drives this binary, so it has to be on PATH.
  home.packages = [ playwright-cli ];

  # Browser automation. Upstream steers coding agents at the CLI + SKILL over
  # the MCP server (cheaper in context: no tool schemas, no accessibility-tree
  # dumps), so that's what we install. `playwright-cli install --skills` is
  # the imperative equivalent and would only write a project-local
  # ./.claude/skills — this puts it in ~/.claude/skills for every repo, and
  # pins it to the same store path as the binary.
  #
  # A directory value gets symlinked wholesale, so the skill's references/
  # come along. Swap to the MCP server instead with:
  #   mcpServers.playwright.command = lib.getExe pkgs.playwright-mcp;
  programs.claude-code.skills.playwright-cli =
    "${playwright-cli}/lib/node_modules/@playwright/cli/skills/playwright-cli";
}
