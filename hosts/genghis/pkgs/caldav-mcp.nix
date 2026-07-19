{ lib, buildNpmPackage, fetchFromGitHub }:

# caldav-mcp (dominik1001) — CalDAV/CardDAV MCP server on ts-caldav, used by the
# Hermes agent for Nextcloud calendar + tasks. Built from a pinned, audited tag
# instead of `npx`-ing it live from npm, so what runs with our creds is fixed
# and reviewable (see the note in hermes.nix mcpServers.calendar).
buildNpmPackage rec {
  pname = "caldav-mcp";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "dominik1001";
    repo = "caldav-mcp";
    rev = "v${version}";
    hash = "sha256-P7WViU0LjVby5YmHxClBXfckGqRVpv6Oml+BPb6ywL4=";
  };

  npmDepsHash = "sha256-KAoJdsCfQnDqg1W3xLkytS6pXjBiI2XzG3nLZVS2P5s=";

  # Strip the ISO-8601 `.datetime({ offset: true })` constraint from every date
  # field. zod compiles it to a JSON-schema `pattern` (a regex); Hermes forwards
  # the tool schema to llama.cpp, which turns the regex into GBNF and fails
  # ("failed to parse grammar" → HTTP 400 on every tool call carrying a date).
  # Plain strings still work — each field's .describe("... ISO 8601") keeps the
  # model formatting them right. --replace-fail so a version bump that changes
  # the call breaks the build loudly rather than silently shipping the bug.
  postPatch = ''
    for f in create-event update-event create-todo update-todo list-todos; do
      substituteInPlace src/tools/$f.ts \
        --replace-fail '.datetime({ offset: true })' ""
    done
  '';

  # `npm ci` would run the `prepare` hook (lefthook install — wants git/network)
  # which the sandbox lacks and the build doesn't need. Skipping lifecycle
  # scripts leaves the explicit `npm run build` (tsc) untouched.
  npmFlags = [ "--ignore-scripts" ];

  meta = {
    description = "CalDAV/CardDAV MCP server, patched to drop the datetime pattern that breaks llama.cpp grammar compilation";
    homepage = "https://github.com/dominik1001/caldav-mcp";
    license = lib.licenses.mit;
    mainProgram = "caldav-mcp";
  };
}
