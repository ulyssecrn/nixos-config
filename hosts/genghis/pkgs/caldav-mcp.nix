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

  # create-todo upstream never passes alarms to ts-caldav (which supports them),
  # so reminders land with no VALARM → no phone alert. This exposes an `alarms`
  # param and auto-adds a display alert at the task time when none is given.
  # Applied before postPatch, which still strips the due/start datetime patterns.
  patches = [ ./caldav-mcp-alarms.patch ];

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

  # ts-caldav only ever emits DURATION (relative) VALARM triggers, which iOS
  # Reminders honours unreliably. Teach its alarm builder to render a non-duration
  # trigger (an ISO datetime) as an ABSOLUTE `TRIGGER;VALUE=DATE-TIME`, so the
  # create-todo default alarm fires at a specific instant. Done in postInstall
  # because node_modules only exists post-install; the global replace hits both
  # the event and todo builders (identical lines). import_ical2 = ts-caldav's
  # bundled ical.js.
  postInstall = ''
    substituteInPlace $out/lib/node_modules/caldav-mcp/node_modules/ts-caldav/dist/index.js \
      --replace-fail 'valarm.addPropertyWithValue("trigger", alarm.trigger);' \
        'if (/^[-+]?P/i.test(alarm.trigger)) { valarm.addPropertyWithValue("trigger", alarm.trigger); } else { const __t = new import_ical2.default.Property("trigger"); __t.setValue(import_ical2.default.Time.fromJSDate(new Date(alarm.trigger), true)); valarm.addProperty(__t); }'
  '';

  meta = {
    description = "CalDAV/CardDAV MCP server, patched to drop the datetime pattern that breaks llama.cpp grammar compilation";
    homepage = "https://github.com/dominik1001/caldav-mcp";
    license = lib.licenses.mit;
    mainProgram = "caldav-mcp";
  };
}
