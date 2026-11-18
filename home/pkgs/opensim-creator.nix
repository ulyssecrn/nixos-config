{ lib, stdenv, fetchurl, autoPatchelfHook, makeDesktopItem, copyDesktopItems
, libGL, vulkan-loader, wayland, libxkbcommon, libdecor, dbus
, libX11, libXcursor, libXext, libXfixes, libXi, libXrandr
}:

# OpenSim Creator (opensimcreator.com). Not in nixpkgs. Uses the generic Linux
# tarball rather than the .deb: same tree, no dpkg unpacking.
stdenv.mkDerivation rec {
  pname = "opensim-creator";
  version = "0.8.0";

  src = fetchurl {
    url = "https://github.com/ComputationalBiomechanicsLab/opensim-creator/releases/download/${version}/opensimcreator-${version}-linux-amd64.tar.xz";
    hash = "sha256-fmdnmhbAKz1g3sI2pSfxgqzqptiXL0E92op308WD3bE=";
  };

  nativeBuildInputs = [ autoPatchelfHook copyDesktopItems ];
  buildInputs = [ stdenv.cc.cc.lib ];

  # The binary only links libc/libm; SDL3 dlopens its video/input backends at
  # runtime, so they must be on the RUNPATH rather than discovered via NEEDED.
  runtimeDependencies = [
    libGL vulkan-loader wayland libxkbcommon libdecor dbus
    libX11 libXcursor libXext libXfixes libXi libXrandr
  ];

  # osc locates ../osc.toml (and thus resources/) via /proc/self/exe, so the
  # tree has to stay intact; $out/bin/osc is just a symlink into it.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/opt $out/bin
    cp -r . $out/opt/opensim-creator
    ln -s $out/opt/opensim-creator/bin/osc $out/bin/osc
    install -Dm644 resources/OpenSimCreator/textures/osc.svg $out/share/icons/hicolor/scalable/apps/opensim-creator.svg
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "opensim-creator";
      desktopName = "OpenSim Creator";
      comment = "Build, edit, and simulate OpenSim models";
      exec = "osc %F";
      icon = "opensim-creator";
      categories = [ "Science" "Education" ];
    })
  ];

  meta = {
    description = "UI for building, editing, and simulating OpenSim models";
    homepage = "https://www.opensimcreator.com";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "osc";
  };
}
