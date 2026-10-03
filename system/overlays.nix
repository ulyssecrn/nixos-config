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
