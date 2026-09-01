# Claude Code, declarative. Was previously hand-maintained in ~/.claude, which
# never reached git — `.claude` is in the global gitignore (home/profiles/base.nix).
#
# hannibal is on stable home-manager (release-26.05), so anything used here has
# to exist in that module too. As of 26.05 it carries the full set — `settings`,
# `skills`, `mcpServers`, `hooks`, `plugins`, `configDir` — so the old
# "enable + settings only" restriction no longer applies. `skills` is still off
# limits here: on stable it IFDs the value, so evaluating the aarch64 hosts from
# genghis fails — per-host module instead, see claude-code-playwright.nix.
#
# settings.json lands as a read-only /nix/store symlink, so Claude Code cannot
# write it back: /config and /model changes apply to the running session only and
# are forgotten on exit. Change them here instead. This is also why
# skipAutoPermissionPrompt is set — the acceptance can't be persisted, so without
# it the auto-mode opt-in dialog would reappear every session.
{ pkgs, ... }:

{
  programs.claude-code = {
    enable = true;
    settings = {
      model = "claude-opus-4-8";
      tui = "fullscreen";
      agentPushNotifEnabled = true;

      # Auto mode: an LLM classifier vets each tool call instead of prompting for
      # every one, still hard-blocking destructive and security-sensitive actions.
      permissions.defaultMode = "auto";
      skipAutoPermissionPrompt = true;

      # model | effort | dir + branch | context bar | 5h/7d usage | reset timer,
      # tokyonight palette. Absolute perl path so it doesn't depend on PATH;
      # `git` is still resolved from PATH, and the branch is simply omitted if
      # it's missing.
      statusLine = {
        type = "command";
        command = "${pkgs.perl}/bin/perl ${./claude-statusline.pl}";
      };
    };
  };
}
