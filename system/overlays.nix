{ config, lib, pkgs, ... }:

{
  # ── Overlays ────────────────────────────────────────────────────────
  nixpkgs.overlays = [ (
    final: prev: {
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

      # pyopenjtalk-plus (calibre → piper-tts → here): one test pins the old
      # TypeError wording ("must be str", now "Expected str, got int"); 1678
      # others pass. Broke loki + atilla on nixpkgs 02c087f (2026-10-20) and
      # stalled the flake-bot lock. Drop once nixpkgs fixes the test.
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pyfinal: pyprev: {
          pyopenjtalk-plus = pyprev.pyopenjtalk-plus.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_run_njd_from_mecab_invalid_input_should_not_break_next_call"
            ];
          });
        })
      ];

      # calibre 9.16.0 on nixpkgs 02c087f: test_file_removal regressed (spine
      # lacks titlepage.xhtml) and test_speech_dispatcher can't import speechd
      # because nixpkgs omits it from installCheckInputs. 671 others pass. The
      # exclusion list is a let-binding inside installCheckPhase, so append to
      # the command itself. Drop once nixpkgs fixes either.
      calibre = prev.calibre.overrideAttrs (oldAttrs: {
        installCheckPhase = builtins.replaceStrings
          [ "python setup.py test " ]
          [ "python setup.py test --exclude-test-name test_file_removal --exclude-test-name test_speech_dispatcher " ]
          oldAttrs.installCheckPhase;
      });

      # anydesk 8.1.0 segfaults in ld.so (SEGV_ACCERR in dl_main) before main:
      # patchelf 0.19.2 doing --set-interpreter + --set-rpath in one pass maps a
      # read-only LOAD over the relocated .dynamic, so writing DT_DEBUG faults.
      # Growing the rpath in its own pass first leaves nixpkgs' combined call
      # nothing to relocate. AnyDesk also re-rolled the 8.1.0 tarball in place,
      # so the nixpkgs hash no longer fetches. Drop once nixpkgs bumps anydesk.
      anydesk = prev.anydesk.overrideAttrs (oldAttrs: {
        src = prev.fetchurl {
          inherit (oldAttrs.src) url;
          hash = "sha256-zS5P2eyTHZY7cBW8mQ2Q6M0lXcx9VZZTtpG3Bb6u7IQ=";
        };
        preFixup = (oldAttrs.preFixup or "") + ''
          patchelf --set-rpath "${lib.makeLibraryPath oldAttrs.buildInputs}" $out/bin/anydesk
        '';
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
