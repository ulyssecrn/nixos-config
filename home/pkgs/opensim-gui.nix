{ lib, stdenvNoCC, fetchurl, unzip, buildFHSEnv, makeDesktopItem, jdk17 }:

# Official OpenSim GUI (simtk.org/projects/opensim). Not in nixpkgs. Upstream
# only ships a Linux build as the 4.6 *beta* (Ubuntu 24.04) — stable 4.6 is
# Windows/macOS only. Asset names embed a build date + commit, so nix-update
# can't track it; bump version/build/hash by hand from
# github.com/opensim-org/opensim-gui/releases.
#
# Runs in an FHS env rather than being autoPatchelf'd: the 3D viewer is
# JxBrowser, which unpacks a stock Chromium out of a jar at runtime and execs
# it — that binary never passes through the build, so only a /lib-shaped
# environment lets it start.
let
  version = "4.6";
  build = "2026-03-20-7107582";

  unwrapped = stdenvNoCC.mkDerivation {
    pname = "opensim-gui-unwrapped";
    inherit version;

    src = fetchurl {
      url = "https://github.com/opensim-org/opensim-gui/releases/download/${version}_beta/OpenSim-${version}-${build}-ub24-linux.zip";
      hash = "sha256-vVcweBh1fcuUwYsMUnHWyoH+9d4sst7YsUYTVS1puPg=";
    };

    nativeBuildInputs = [ unzip jdk17 ];

    # The release zip wraps a second zip holding the actual tree.
    unpackPhase = ''
      unzip -q $src
      unzip -q opensim.zip
    '';

    # Upstream bug in the Linux beta: the viewer module's Class-Path lists the
    # mac-arm/win64 JxBrowser binary jars but not linux64 (which *is* shipped),
    # so the viewer dies with "No JAR file with the platform binaries".
    installPhase = ''
      echo "Class-Path: ext/jxbrowser-7.44.1.jar ext/jxbrowser-swing-7.44.1.jar ext/jxbrowser-linux64-7.44.1.jar" > cp.mf
      jar ufm opensim/opensim/modules/org-opensim-javabrowser.jar cp.mf

      mkdir -p $out/opt
      cp -r opensim $out/opt/opensim-gui
      install -Dm644 opensim/OpenSimLogoWhiteNoText.png $out/share/pixmaps/opensim.png
    '';

    dontPatchELF = true;
    dontStrip = true;
  };

  desktopItem = makeDesktopItem {
    name = "opensim";
    desktopName = "OpenSim";
    comment = "Neuromusculoskeletal modeling, simulation, and analysis";
    exec = "opensim";
    icon = "opensim";
    categories = [ "Science" "Education" ];
  };
in
buildFHSEnv {
  pname = "opensim";
  inherit version;

  targetPkgs = pkgs: with pkgs; [
    jdk17
    blas lapack gfortran.cc.lib stdenv.cc.cc.lib
    # JxBrowser's Chromium
    glib nss nspr dbus atk at-spi2-atk at-spi2-core cups expat libdrm mesa
    libgbm libxkbcommon pango cairo gtk3 alsa-lib udev fontconfig freetype libGL
    libX11 libXcomposite libXdamage libXext libXfixes libXrandr libxcb libXtst
    libXi libXrender libXcursor libxshmfence
  ];

  # Upstream targets Java 8, but Java 8 can't scale Swing on Linux and loki's
  # XWayland apps get no compositor scaling (force_zero_scaling), so the UI was
  # unreadably tiny with unantialiased fonts. JDK 17 runs it fine (NetBeans
  # platform 22) and honours uiScale; 1.5 matches loki's eDP-1 scale.
  # FlatLaf instead of the default GTK LaF: GTK3 loaded in-process rounds the
  # 1.5 scale up to 2 and resets the X cursor size to 24×2, doubling the cursor.
  runScript = "${unwrapped}/opt/opensim-gui/bin/opensim --jdkhome ${jdk17}/lib/openjdk --laf com.formdev.flatlaf.FlatLightLaf -J-Dsun.java2d.uiScale=1.5 -J-Dawt.useSystemAAFontSettings=on -J-Dswing.aatext=true";

  extraInstallCommands = ''
    install -Dm644 ${desktopItem}/share/applications/opensim.desktop -t $out/share/applications
    install -Dm644 ${unwrapped}/share/pixmaps/opensim.png -t $out/share/pixmaps
  '';

  meta = {
    description = "Neuromusculoskeletal modeling, simulation, and analysis (official GUI)";
    homepage = "https://simtk.org/projects/opensim";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode lib.sourceTypes.binaryBytecode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "opensim";
  };
}
