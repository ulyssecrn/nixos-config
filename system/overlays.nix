{ config, lib, pkgs, ... }:

{
  # ── Overlays ────────────────────────────────────────────────────────
  nixpkgs.overlays = [ (
    final: prev: {
      # claude-code: temporary bump to 2.1.280. nixpkgs-unstable is still on
      # 2.1.278, which the API now rejects for the newer models
      # ("claude_code_version_too_old", needs >= 2.1.280); the fix is already on
      # nixpkgs master. The package reads its version + per-platform checksums
      # from a bundled `manifest.zst.json`, so overriding that arg with master's
      # values is enough — no rebuild, just a different prebuilt binary URL.
      # linux-arm64 covers odin (aarch64 on Asahi); the fleet has no darwin.
      #
      # Gated on the exact broken pin so this is self-deactivating: it engages
      # only while unstable sits on 2.1.278, and falls back to stock the moment
      # the channel moves off it (delete the block then — see TODO.md). The gate
      # also skips hannibal, whose nixos-raspberrypi nixpkgs still ships the
      # older, pre-`manifest` packaging (2.1.187) that has no `manifest` arg to
      # override — and which doesn't need the bump anyway.
      claude-code =
        if prev.claude-code.version == "2.1.278"
        then prev.claude-code.override {
          manifest = {
            version = "2.1.280";
            platforms = {
              linux-x64 = {
                binary = "claude.zst";
                checksum = "27910e2ae704d8f2e8024897d8fdf1e7710807baf4f6982c0e3797c058315384";
              };
              linux-arm64 = {
                binary = "claude.zst";
                checksum = "6a01f30418f35122a672ccf74bed64aba5119ad47c71548a3b447cc9fec48c81";
              };
            };
          };
        }
        else prev.claude-code;

      # paperless-ngx: re-disable a flaky test the nixpkgs 3.1.3 bump dropped.
      # `testNormalOperation` is a non-deterministic count assertion (was
      # "4 != 3" on 3.0.5, now "12 != 11" on 3.1.3) that upstream already had in
      # disabledTests for 3.0.5 and silently dropped when bumping to 3.1.3 —
      # 3266 pass, this one fails, breaking atilla's build and stalling the
      # flake-bot lock. `-k` deselection is harmless on versions where the test
      # is absent, so this is safe to leave until upstream re-disables it.
      paperless-ngx = prev.paperless-ngx.overrideAttrs (oldAttrs: {
        disabledTests = (oldAttrs.disabledTests or [ ]) ++ [ "testNormalOperation" ];
      });

      # Dolphin fix for MIME apps support
      # https://discourse.nixos.org/t/dolphin-does-not-have-mime-associations/
      kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
          dolphin = kprev.dolphin.overrideAttrs (oldAttrs: {
            nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
            postInstall = (oldAttrs.postInstall or "") + ''
              wrapProgram $out/bin/dolphin \
                --set XDG_CONFIG_DIRS "${kprev.plasma-workspace}/etc/xdg:$XDG_CONFIG_DIRS" \
                --set XDG_MENU_PREFIX "plasma-" \
                --run "${kprev.kservice}/bin/kbuildsycoca6 --noincremental ${kprev.plasma-workspace}/etc/xdg/menus/plasma-applications.menu"
            '';
          });
        });
    }
    )
  ];
}
