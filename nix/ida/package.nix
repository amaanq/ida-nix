{ pkgs }:
{
  release,
  resolvedPython,
  source,
  customizations ? { },
  extraRuntimeDependencies ? [ ],
}:
let
  inherit (pkgs) lib;
  files = customizations.files or [ ];
  hexPatches = customizations.hexPatches or [ ];
  hasOnlyAttrs =
    allowed: value: lib.all (name: builtins.elem name allowed) (builtins.attrNames value);
  isRelativePath =
    value:
    builtins.isString value
    && value != ""
    && !lib.hasPrefix "/" value
    && !lib.hasInfix "\n" value
    && !lib.hasInfix "\r" value
    && lib.all (component: component != "" && component != "." && component != "..") (
      lib.splitString "/" value
    );
  isHex =
    value:
    builtins.isString value
    && value != ""
    && lib.mod (builtins.stringLength value) 2 == 0
    && builtins.match "[0-9a-fA-F]+" value != null;
  validFile =
    file:
    builtins.isAttrs file
    && hasOnlyAttrs [
      "source"
      "target"
    ] file
    && file ? source
    && (
      builtins.isPath file.source
      || lib.isDerivation file.source
      || (builtins.isString file.source && builtins.hasContext file.source)
    )
    && file ? target
    && isRelativePath file.target;
  validHexPatch =
    patch:
    builtins.isAttrs patch
    && hasOnlyAttrs [
      "assertCount"
      "filename"
      "from"
      "to"
    ] patch
    && patch ? filename
    && isRelativePath patch.filename
    && patch ? from
    && isHex patch.from
    && patch ? to
    && isHex patch.to
    && builtins.stringLength patch.from == builtins.stringLength patch.to
    && builtins.isInt (patch.assertCount or 1)
    && (patch.assertCount or 1) > 0;
  fileTargets = map (file: file.target) files;
  installFiles = lib.concatMapStringsSep "\n" (file: ''
    install -Dm644 ${file.source} "$idaRoot"/${lib.escapeShellArg file.target}
  '') files;
  patchFiles = lib.concatMapStringsSep "\n" (
    patch:
    let
      assertCount = toString (patch.assertCount or 1);
    in
    ''
      perl -0777 -pi -e 'my $expected = ${assertCount}; my $count = (s/\Q''${\pack("H*","${patch.from}")}\E/''${\pack("H*","${patch.to}")}/g) || 0; die "Expected $expected substitutions, did $count\n" if $count != $expected' "$idaRoot"/${lib.escapeShellArg patch.filename}
    ''
  ) hexPatches;
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

    nativeBuildInputs =
      (with pkgs; [
        autoPatchelfHook
        copyDesktopItems
        makeWrapper
        qt6.wrapQtAppsHook
      ])
      ++ lib.optional (hexPatches != [ ]) pkgs.perl;

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

      ${installFiles}
      ${patchFiles}

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
assert lib.assertMsg (builtins.isAttrs customizations)
  "ida-nix customizations must be an attribute set";
assert lib.assertMsg (hasOnlyAttrs [
  "files"
  "hexPatches"
] customizations) "ida-nix customizations contains an unknown attribute";
assert lib.assertMsg (builtins.isList files) "ida-nix customizations.files must be a list";
assert lib.assertMsg (lib.all validFile files)
  "ida-nix customizations.files contains an invalid file";
assert lib.assertMsg (
  builtins.length fileTargets == builtins.length (lib.unique fileTargets)
) "ida-nix customizations.files contains duplicate targets";
assert lib.assertMsg (builtins.isList hexPatches)
  "ida-nix customizations.hexPatches must be a list";
assert lib.assertMsg (lib.all validHexPatch hexPatches)
  "ida-nix customizations.hexPatches contains an invalid patch";
ida
