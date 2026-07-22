{ lib, buildNpmPackage, fetchFromGitHub }:

# imap-mini-mcp (florianbuetow) — a read-focused IMAP MCP server built for Proton
# Mail Bridge, used by the Hermes agent to read personal mail over the Bridge's
# local IMAP (127.0.0.1:1143). Built from pinned, audited source (no npm release
# exists — pinned to a commit) instead of npx-from-npm, same as caldav-mcp: what
# runs with your mail creds is fixed and reviewable.
#
# Upstream ships 17 tools incl. non-destructive writes (move/star/create-folder/
# draft) — it can never send or delete, but you asked for strictly read-only, so
# the postPatch filters the single tool registry down to the 5 read tools. Because
# both the advertised ListTools set AND the dispatch map derive from that registry,
# a write verb is neither offered nor callable (dispatch returns "Unknown tool").
buildNpmPackage rec {
  pname = "imap-mini-mcp";
  version = "0.1.0-cc37da4";

  src = fetchFromGitHub {
    owner = "florianbuetow";
    repo = "imap-mini-mcp";
    rev = "cc37da4599a976e89c13dbcea1395190f7111a44";
    hash = "sha256-ZSN9LAjWNAhL8qruuSIn1wgCu8yLX60CUyWQ9HtMmKM=";
  };

  npmDepsHash = "sha256-Mh8oL07lyrjpHsZNNpVZursZpnz2xQRSXA+XWtC2qy0=";

  # Read-only: keep only the 5 read tools in the registry. --replace-fail so a
  # source refactor that moves these anchors breaks the build loudly instead of
  # silently re-exposing the write tools.
  postPatch = ''
    substituteInPlace src/tools/index.ts \
      --replace-fail 'export const tools = registry.map(' \
'const READ_ONLY_TOOLS = new Set(["find_emails", "fetch_email_content", "fetch_email_attachment", "list_folders", "list_starred_emails"]);
const readOnlyRegistry = registry.filter((t) => READ_ONLY_TOOLS.has(t.name));
export const tools = readOnlyRegistry.map('
    substituteInPlace src/tools/index.ts \
      --replace-fail 'registry.map((t) => [t.name, t.handler])' \
      'readOnlyRegistry.map((t) => [t.name, t.handler])'
  '';

  meta = {
    description = "Read-only IMAP MCP server (patched from imap-mini-mcp) for reading Proton Bridge mail";
    homepage = "https://github.com/florianbuetow/imap-mini-mcp";
    license = lib.licenses.mit;
    mainProgram = "imap-mini-mcp";
  };
}
