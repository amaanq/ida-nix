{ pkgs }:
{
  release,
  python,
  installer,
  files ? [ ],
  hexPatches ? [ ],
  extraRuntimeDependencies ? [ ],
}:
let
  inherit (pkgs) lib;
  inherit (import ../hex-patches.nix { inherit lib; }) mkHexPatcher;
  hexPatcher = mkHexPatcher { inherit hexPatches pkgs; };
  qtBasePluginPath = "${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}";
  runtimeDependencies =
    with pkgs;
    [
      alsa-lib
      at-spi2-atk
      cairo
      curl
      dbus
      fontconfig
      freetype
      glib
      gtk3
      libGL
      libdrm
      libice
      libkrb5
      libsecret
      libsm
      libunwind
      libx11
      libxau
      libxcb
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libxcb-wm
      libxext
      libxi
      libxkbcommon
      libxrender
      openssl
      qt6.qtbase
      qt6.qtwayland
      stdenv.cc.cc
      zlib
      python
    ]
    ++ extraRuntimeDependencies;
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "ida-pro-unwrapped";
  inherit (release) version;
  src = installer;

  dontUnpack = true;
  strictDeps = true;
  dontWrapQtApps = true;

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    copyDesktopItems
    makeWrapper
    qt6.wrapQtAppsHook
  ];

  buildInputs = runtimeDependencies;
  inherit runtimeDependencies;

  desktopItems = [
    (pkgs.makeDesktopItem {
      name = "ida-pro";
      desktopName = "IDA Pro";
      genericName = "Interactive Disassembler";
      comment = "Interactive disassembler and debugger";
      exec = "ida %F";
      icon = "ida-pro";
      categories = [ "Development" ];
      startupWMClass = "IDA";
    })
  ];

  installPhase = ''
    runHook preInstall

    idaRoot="$out/opt/ida"
    mkdir -p "$idaRoot" "$out/bin" "$out/lib"
    export HOME="$idaRoot"

    "$(< "$NIX_CC/nix-support/dynamic-linker")" "$src" --mode unattended --prefix "$idaRoot"
    test -x "$idaRoot/ida"

    ${lib.concatMapStrings (file: ''
      install -Dm644 ${file.source} "$idaRoot"/${lib.escapeShellArg file.target}
    '') files}
    ${lib.optionalString (hexPatches != [ ]) ''${lib.getExe hexPatcher} "$idaRoot"''}

    addAutoPatchelfSearchPath "$idaRoot"
    shopt -s nullglob
    for library in "$idaRoot"/*.so "$idaRoot"/*.so.*; do
      ln -s "$library" "$out/lib/"
    done

    for program in ida idat; do
      if [ -x "$idaRoot/$program" ]; then
        makeWrapper "$idaRoot/$program" "$out/bin/$program" \
          --set IDADIR "$idaRoot" \
          --prefix LD_LIBRARY_PATH : "$idaRoot:${lib.makeLibraryPath runtimeDependencies}" \
          --prefix PATH : "${python}/bin" \
          --prefix QT_PLUGIN_PATH : "$idaRoot/plugins:${qtBasePluginPath}"
      fi
    done

    for icon in "$idaRoot"/appico.png "$idaRoot"/ida.png; do
      if [ -f "$icon" ]; then
        install -Dm644 "$icon" "$out/share/icons/hicolor/128x128/apps/ida-pro.png"
        break
      fi
    done

    runHook postInstall
  '';

  passthru.ida = rec {
    inherit python;
    root = "${finalAttrs.finalPackage}/opt/ida";
    qtPluginPath = "${root}/plugins:${qtBasePluginPath}";
    runtimeLibraryPath = "${root}:${lib.makeLibraryPath runtimeDependencies}";
  };

  meta = {
    description = "IDA Pro interactive disassembler and debugger";
    homepage = "https://hex-rays.com/ida-pro/";
    license = release.license or lib.licenses.unfree;
    mainProgram = "ida";
    platforms = release.systems;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
