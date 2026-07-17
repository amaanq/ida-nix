{
  mkIdaPlugin,
  python,
}:
let
  capa = python.pkgs.capa;
  pluginSource = "${capa}/${python.sitePackages}/capa/ida/plugin";
in
mkIdaPlugin {
  id = "capa-explorer";
  pname = "ida-plugin-capa-explorer";
  inherit (capa) version;
  src = capa;
  dontUnpack = true;

  artifacts = [
    {
      root = "plugins";
      path = "capa_explorer.py";
    }
    {
      root = "plugins";
      path = "capa-explorer.json";
      entrypoint = false;
    }
  ];
  idaVersions = {
    min = "8.0";
    maxExclusive = "10.0";
  };
  pythonAbi = python.pythonVersion;
  pythonPackages = [ capa ];

  installPhase = ''
    runHook preInstall
    install -Dm644 \
      "${pluginSource}/capa_explorer.py" \
      "$out/share/ida/plugins/capa_explorer.py"
    install -Dm644 \
      "${pluginSource}/ida-plugin.json" \
      "$out/share/ida/plugins/capa-explorer.json"
    runHook postInstall
  '';

  meta = {
    description = "capa capability explorer for IDA Pro";
    homepage = "https://github.com/mandiant/capa";
    license = python.pkgs.lib.licenses.asl20;
  };
}
