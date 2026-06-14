{ config, lib, pkgs, ... }:

{
  # ── Overlays ────────────────────────────────────────────────────────
  nixpkgs.overlays = [ (
    final: prev: {
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

      # openscad 2021.01 link error vs EGL-enabled glew. Fixed on master in
      # nixpkgs#530580 (merged 2026-06-11); replicate the override locally
      # until nixos-unstable catches up, then this block can be removed.
      # https://github.com/NixOS/nixpkgs/issues/530529
      openscad = prev.openscad.override {
        glew = prev.glew.override { enableEGL = false; };
      };
    }
    )
  ];
}
