{
  bindiff,
  bindiffSrc,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "ida-plugin-bindiff";
  inherit (bindiff) version;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 -t "$out/share/ida/plugins" \
      ${bindiff}/share/bindiff/plugins/idapro/{bindiff8_ida64,binexport12_ida64}.so
    install -Dm644 ${bindiffSrc}/LICENSE "$out/share/licenses/ida-plugin-bindiff/LICENSE"
    runHook postInstall
  '';

  passthru.idaPlugin = {
    runtimePackages = [ bindiff ];
    commands = [ "${bindiff}/bin/bindiff" ];
  };

  meta = bindiff.meta // {
    description = "BinDiff and BinExport plugins for IDA 9.2 through 9.4";
  };
}
