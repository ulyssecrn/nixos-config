{ lib, buildNpmPackage, fetchFromGitHub, makeWrapper, chromium }:

# @playwright/cli — the CLI half of Playwright's agent tooling. Upstream now
# points coding agents here rather than at playwright-mcp: a SKILL plus ~60
# short commands costs far less context than an MCP server's tool schemas and
# accessibility-tree dumps (see the "Playwright CLI vs Playwright MCP" section
# in both READMEs). The tarball also ships the SKILL.md we hand to Claude Code
# from claude-code.nix, so binary and skill are always the same version.
#
# Not in nixpkgs (only playwright-mcp is), hence this derivation.
buildNpmPackage rec {
  pname = "playwright-cli";
  version = "0.1.18";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "playwright-cli";
    tag = "v${version}";
    hash = "sha256-E/AzDJhD12PWSaA3iRY+hloPsSWnAw18gTa/ItVhr3E=";
  };

  npmDepsHash = "sha256-3kqiQvGtZfsmLHVWeCSM1yOYb+ws2x1vMPC1OuvrKAI=";

  # Pure JS, no compile step; package.json's only script is `test`.
  dontNpmBuild = true;
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ];

  # Two things are broken out of the box on NixOS:
  #
  #  1. The default browser is the `chrome` *channel*, i.e. a system Chrome at
  #     /opt/google/chrome/chrome. There isn't one.
  #  2. Pointing it at pkgs.playwright-driver.browsers doesn't help either:
  #     this release pins playwright-core 1.63.0-alpha, which wants chromium
  #     revision 1237, while nixpkgs' driver is 1.61.1 / revision 1228.
  #
  # So aim it at nixpkgs chromium instead. These are the env vars playwright's
  # shared cli-client config loader reads (same ones playwright-mcp documents);
  # --set-default so a project's .playwright/cli.config.json, or an explicit
  # `--config`, still wins.
  postInstall = ''
    wrapProgram $out/bin/playwright-cli \
      --set-default PLAYWRIGHT_MCP_BROWSER chromium \
      --set-default PLAYWRIGHT_MCP_EXECUTABLE_PATH ${lib.getExe chromium}
  '';

  meta = {
    description = "Playwright browser automation as a CLI + agent skill";
    homepage = "https://github.com/microsoft/playwright-cli";
    license = lib.licenses.asl20;
    mainProgram = "playwright-cli";
  };
}
