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

      # GDAL 3.13.1's zarr sharding test (test_zarr_read_simple_sharding) is
      # broken on unstable, failing the check phase. It cascades through
      # pdal → vtk → freecad and breaks the loki build (freecad is in loki's home
      # packages). Skip GDAL's checks until nixpkgs disables the test upstream,
      # then remove this. Both variants overridden since the freecad chain pulls
      # gdalMinimal. https://github.com/NixOS/nixpkgs/issues/540609
      gdal        = prev.gdal.overrideAttrs        (_: { doCheck = false; doInstallCheck = false; });
      gdalMinimal = prev.gdalMinimal.overrideAttrs (_: { doCheck = false; doInstallCheck = false; });
    }
    )
  ];
}
