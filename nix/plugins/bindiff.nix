{
  bindiffPackage,
  bindiffSrc,
  mkIdaPlugin,
}:
mkIdaPlugin {
  id = "bindiff";
  pname = "ida-plugin-bindiff";
  inherit (bindiffPackage) version;
  src = bindiffPackage;
  dontUnpack = true;

  artifacts = [
    {
      root = "plugins";
      path = "bindiff8_ida64.so";
    }
    {
      root = "plugins";
      path = "binexport12_ida64.so";
    }
  ];
  idaVersions = {
    min = "9.2";
    maxExclusive = "9.5";
  };
  commands = [
    {
      name = "bindiff";
      package = bindiffPackage;
      path = "bin/bindiff";
    }
  ];
  runtimePackages = [ bindiffPackage ];

  installPhase = ''
    runHook preInstall
    install -Dm755 \
      "$src/share/bindiff/plugins/idapro/bindiff8_ida64.so" \
      "$out/share/ida/plugins/bindiff8_ida64.so"
    install -Dm755 \
      "$src/share/bindiff/plugins/idapro/binexport12_ida64.so" \
      "$out/share/ida/plugins/binexport12_ida64.so"
    install -Dm644 \
      "${bindiffSrc}/LICENSE" \
      "$out/share/licenses/ida-plugin-bindiff/LICENSE"
    runHook postInstall
  '';

  meta = bindiffPackage.meta // {
    description = "BinDiff and BinExport plugins for IDA 9.2 through 9.4";
  };
}
