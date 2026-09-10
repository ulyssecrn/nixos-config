# Fleet-wide agent skills — pure-markdown skill packs shared across all three
# coding agents. A "skill" is just a folder holding a SKILL.md (an agent-neutral
# open format), so the exact same folder works in Claude Code, Codex and
# OpenCode; only the directory each reads it from differs (~/.claude/skills,
# ~/.codex/skills, ~/.config/opencode/skills). This is the nix-native equivalent
# of `npx skills add <owner>/<repo>`: pin the repo as a `flake = false` input
# (see flake.nix) so the flake-bot bumps it weekly, then point all three agents
# at its skill folders here.
#
# Each agent's home-manager `skills` option takes an attrset { <name> = <dir>; }
# and symlinks each entry into its own skills dir, leaving that dir writable so
# skills you add by hand (or with `npx skills add`) still coexist. A store-path
# *string* that points at a directory is symlinked wholesale (references/ etc.
# come along); a bare string would instead be written verbatim as SKILL.md, so
# the value must resolve to a directory.
#
# Only for skill packs that are *just docs*. A skill bundled with a binary it
# drives (needs the tool on PATH, and a build) lives with its package instead —
# see ./playwright.nix. To add another doc pack: add a `flake = false` input in
# flake.nix and one more `skillsFrom` line below.
{ inputs, lib, ... }:

let
  # A skills repo lays its skills out as skills/<name>/SKILL.md. Turn that root
  # into { <name> = "<root>/<name>"; } by reading it at eval time — the input is
  # already realised in the store, so this is a stat, not an import-from-
  # derivation build.
  skillsFrom =
    root:
    lib.mapAttrs (name: _type: "${root}/${name}") (
      lib.filterAttrs (_name: type: type == "directory") (builtins.readDir root)
    );

  # KiCad automation — schematic / PCB / BOM / Gerber review, exports, panelize.
  skills = skillsFrom "${inputs.kistack}/skills";
in
{
  programs.claude-code.skills = skills;
  programs.codex.skills = skills;
  programs.opencode.skills = skills;
}
