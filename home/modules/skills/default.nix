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

  # kistack's part-selection skills (bom, schematic, …) need a pcbparts MCP
  # (github:Averyy/pcbparts-mcp — the maintainer's hosted endpoint) to resolve
  # real components. Declared once in the shared programs.mcp registry and pulled
  # into each harness by its own enableMcpIntegration flag (all default off). Its
  # tool schemas load into every claude-code/opencode session on every host —
  # scope this to a PCB host if that context cost bites.
  #
  # codex is left out on purpose: integrating it makes home-manager write a
  # read-only ~/.codex/config.toml, which would stop codex persisting its own
  # per-project trust + /model state (unlike claude-code, codex keeps that mutable
  # state in the same file as settings — codex.nix leaves it writable on purpose).
  # codex gets the same MCP imperatively instead, into that writable file:
  #   codex mcp add pcbparts --url https://pcbparts.dev/mcp
  programs.mcp = {
    enable = true;
    servers.pcbparts.url = "https://pcbparts.dev/mcp";
  };
  programs.claude-code.enableMcpIntegration = true;
  programs.opencode.enableMcpIntegration = true;
}
