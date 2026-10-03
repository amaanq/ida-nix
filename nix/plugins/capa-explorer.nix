{
  lib,
  python,
  stdenvNoCC,
}:
let
  inherit (python.pkgs) capa;
  pluginSource = "${capa}/${python.sitePackages}/capa/ida/plugin";
in
stdenvNoCC.mkDerivation {
  pname = "ida-plugin-capa-explorer";
  inherit (capa) version;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 ${pluginSource}/capa_explorer.py "$out/share/ida/plugins/capa_explorer.py"
    install -Dm644 ${pluginSource}/ida-plugin.json "$out/share/ida/plugins/capa-explorer.json"
    runHook postInstall
  '';

  passthru.idaPlugin.pythonPackages = [ capa ];

  meta = {
    description = "capa capability explorer for IDA Pro";
    homepage = "https://github.com/mandiant/capa";
    license = lib.licenses.asl20;
    inherit (capa.meta) broken;
  };
}
