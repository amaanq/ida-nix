{ pkgs }:
{
  release,
  resolvedPython,
  source,
  extraRuntimeDependencies ? [ ],
}:
let
  inherit (pkgs) lib;
  runtimeDependencies =
    (
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
      ]
      ++ [ resolvedPython ]
    )
    ++ extraRuntimeDependencies;
  desktopItem = pkgs.makeDesktopItem {
    name = "ida-pro";
    desktopName = "IDA Pro";
    genericName = "Interactive Disassembler";
    comment = "Interactive disassembler and debugger";
    exec = "ida %F";
    icon = "ida-pro";
    categories = [ "Development" ];
    startupWMClass = "IDA";
  };
  ida = pkgs.stdenv.mkDerivation {
    pname = "ida-pro-unwrapped";
    inherit (release) version;
    src = source;

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
    desktopItems = [ desktopItem ];

    installPhase = ''
      runHook preInstall

      idaRoot="$out/opt/ida"
      mkdir -p "$idaRoot" "$out/bin" "$out/lib"
      export HOME="$idaRoot"

      dynamicLinker="$(< "$NIX_CC/nix-support/dynamic-linker")"
      "$dynamicLinker" "$src" --mode unattended --prefix "$idaRoot"

      if [ ! -x "$idaRoot/ida" ]; then
        echo "IDA installer did not create $idaRoot/ida" >&2
        exit 1
      fi

      addAutoPatchelfSearchPath "$idaRoot"

      shopt -s nullglob
      for library in "$idaRoot"/*.so "$idaRoot"/*.so.*; do
        ln -s "$library" "$out/lib/$(basename "$library")"
      done

      runtimeLibraryPath="${lib.makeLibraryPath runtimeDependencies}"
      qtPluginPath="$idaRoot/plugins:${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}"

      for program in ida idat; do
        if [ -x "$idaRoot/$program" ] && [ ! -d "$idaRoot/$program" ]; then
          makeWrapper "$idaRoot/$program" "$out/bin/$program" \
            --set IDADIR "$idaRoot" \
            --prefix LD_LIBRARY_PATH : "$idaRoot:$runtimeLibraryPath" \
            --prefix PATH : "${resolvedPython}/bin" \
            --prefix QT_PLUGIN_PATH : "$qtPluginPath"
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

    passthru = {
      ida = {
        inherit (release) pythonAbi;
        inherit release;
        python = resolvedPython;
        qtPluginPath = "${ida}/opt/ida/plugins:${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}";
        root = "${ida}/opt/ida";
        runtimeLibraryPath = lib.makeLibraryPath runtimeDependencies;
      };
    };

    meta = {
      description = "IDA Pro interactive disassembler and debugger";
      homepage = "https://hex-rays.com/ida-pro/";
      license = release.license or lib.licenses.unfree;
      mainProgram = "ida";
      platforms = release.systems;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
in
ida
