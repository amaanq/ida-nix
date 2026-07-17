{
  mkIdaPlugin,
  python,
  src,
}:
let
  package = python.pkgs.buildPythonApplication {
    pname = "ida-pro-mcp";
    version = "2.0.0";
    pyproject = true;
    inherit src;

    build-system = [ python.pkgs.setuptools ];
    dependencies = [
      python.pkgs.idapro
      python.pkgs.tomli-w
    ];

    postInstall = ''
      ln -s ida_pro_mcp/ida_mcp "$out/${python.sitePackages}/ida_mcp"
      PYTHONPATH="$out/${python.sitePackages}:$PYTHONPATH" \
        ${python.interpreter} -c 'import ida_pro_mcp.server'
      install -Dm644 LICENSE "$out/share/licenses/ida-pro-mcp/LICENSE"
    '';

    pythonImportsCheck = [ "ida_pro_mcp" ];
    doCheck = false;

    meta = {
      description = "MCP and idalib servers for IDA Pro";
      homepage = "https://github.com/mrexodia/ida-pro-mcp";
      license = python.pkgs.lib.licenses.mit;
      mainProgram = "ida-pro-mcp";
    };
  };

  plugin = mkIdaPlugin {
    id = "ida-pro-mcp";
    pname = "ida-plugin-ida-pro-mcp";
    inherit (package) version;
    inherit src;

    artifacts = [
      {
        root = "plugins";
        path = "ida_pro_mcp.py";
      }
    ];
    commands =
      map
        (name: {
          inherit name package;
          path = "bin/${name}";
        })
        [
          "ida-pro-mcp"
          "idalib-mcp"
        ];
    idaVersions.min = "8.3";
    pythonAbi = python.pythonVersion;
    pythonPackages = [ (python.pkgs.toPythonModule package) ];
    requiresDecompiler = true;

    installPhase = ''
      runHook preInstall
      install -Dm644 \
        src/ida_pro_mcp/ida_mcp.py \
        "$out/share/ida/plugins/ida_pro_mcp.py"
      install -Dm644 \
        LICENSE \
        "$out/share/licenses/ida-plugin-ida-pro-mcp/LICENSE"
      runHook postInstall
    '';

    meta = {
      description = "IDA bridge for the ida-pro-mcp server";
      homepage = "https://github.com/mrexodia/ida-pro-mcp";
      license = python.pkgs.lib.licenses.mit;
    };
  };
in
{
  inherit package plugin;
}
