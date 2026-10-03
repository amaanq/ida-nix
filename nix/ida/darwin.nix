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
  libpython = "${python}/lib/lib${python.libPrefix}.dylib";
in
assert lib.assertMsg (
  extraRuntimeDependencies == [ ]
) "ida-nix: extraRuntimeDependencies only applies to the Linux build";
pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ida-pro-unwrapped";
  inherit (release) version;
  src = installer;

  dontUnpack = true;
  # stripping or rewriting install names would invalidate the signatures
  dontFixup = true;

  nativeBuildInputs = with pkgs; [
    cctools
    darwin.sigtool
    makeWrapper
    unzip
  ];

  installPhase = ''
    runHook preInstall

    appRoot="$out/opt/ida.app"
    idaRoot="$appRoot/Contents/MacOS"
    mkdir -p "$out/opt" "$out/bin" "$out/lib"
    export HOME="$TMPDIR"

    unzip -q "$src" -d "$TMPDIR/installer"
    "$TMPDIR"/installer/*.app/Contents/MacOS/osx-${pkgs.stdenv.hostPlatform.darwinArch} \
      --mode unattended --prefix "$TMPDIR/prefix"
    mv "$TMPDIR"/prefix/*.app "$appRoot"
    test -x "$idaRoot/ida"

    ${lib.concatMapStrings (file: ''
      install -Dm644 ${file.source} "$idaRoot"/${lib.escapeShellArg file.target}
    '') files}
    ${lib.optionalString (hexPatches != [ ]) ''${lib.getExe hexPatcher} "$idaRoot"''}
    for patched in ${lib.escapeShellArgs (lib.unique (map (patch: patch.filename) hexPatches))}; do
      case "$(od -An -tx1 -N4 "$idaRoot/$patched" | tr -d ' ')" in
        cffaedfe | cafebabe) codesign -f -s - "$idaRoot/$patched" ;;
      esac
    done

    shopt -s nullglob
    for library in "$idaRoot"/*.dylib; do
      ln -s "$library" "$out/lib/"
    done

    for program in ida idat; do
      if [ -x "$idaRoot/$program" ]; then
        makeWrapper "$idaRoot/$program" "$out/bin/$program" \
          --set IDADIR "$idaRoot" \
          --set DYLD_INSERT_LIBRARIES ${libpython} \
          --prefix PATH : ${python}/bin \
          --prefix QT_PLUGIN_PATH : "$appRoot/Contents/PlugIns"
      fi
    done

    runHook postInstall
  '';

  passthru.ida =
    let
      app = "${finalAttrs.finalPackage}/opt/ida.app";
      root = "${app}/Contents/MacOS";
    in
    {
      inherit app python root;
      qtPluginPath = "${app}/Contents/PlugIns";
      runtimeLibraryPath = root;
    };

  meta = {
    description = "IDA Pro interactive disassembler and debugger";
    homepage = "https://hex-rays.com/ida-pro/";
    license = release.license or lib.licenses.unfree;
    mainProgram = "ida";
    platforms = lib.intersectLists (lib.attrNames release.installers) lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
