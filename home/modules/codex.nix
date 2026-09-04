# Codex, imported fleet-wide via home/profiles/base.nix alongside opencode and
# claude-code. Deliberately sets no `settings`: home-manager would write
# ~/.codex/config.toml as a read-only /nix/store symlink, which stops codex from
# persisting its own `/model`, approval-mode and login state. Auth (auth.json)
# lives beside it and stays writable either way.
#
# hannibal is on stable home-manager (release-26.05) and stable nixpkgs, so it
# gets an older codex (0.133 vs 0.149); only `enable`/`package` are used here,
# and both branches carry those.
{
  programs.codex.enable = true;
}
