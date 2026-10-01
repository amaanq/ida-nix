{
  fetchFromGitHub,
  fetchPypi,
  lib,
  python,
  stdenvNoCC,
}:
let
  inherit (python.pkgs) buildPythonPackage hatchling;

  ida-domain = python.pkgs.ida-domain.overridePythonAttrs (old: {
    version = "0.5.1";
    src = fetchFromGitHub {
      owner = "HexRaysSA";
      repo = "ida-domain";
      tag = "v0.5.1";
      hash = "sha256-vlVJnRaRNMelQ3w1SgCDvtIQJKBuULLOqKKdAvDK2y4=";
    };
    build-system = [ hatchling ];
    dependencies = old.dependencies ++ [ python.pkgs.typing-extensions ];
  });

  zeromcp = buildPythonPackage (finalAttrs: {
    pname = "zeromcp";
    version = "1.10.3";
    pyproject = true;
    src = fetchPypi {
      inherit (finalAttrs) pname version;
      hash = "sha256-cSMdstEy4+AuOxCuHLSISa/271q73gf/0j0QcaysuuY=";
    };
    build-system = [ hatchling ];
    pythonImportsCheck = [ "zeromcp" ];
    meta.license = lib.licenses.mit;
  });

  ida-nexus = buildPythonPackage (finalAttrs: {
    pname = "ida-nexus";
    version = "0.13.1";
    pyproject = true;
    src = fetchPypi {
      pname = "ida_nexus";
      inherit (finalAttrs) version;
      hash = "sha256-UW6T1SfkbqDDXWMM8HmbIncvrrqp2SHQK/ne24yD03E=";
    };
    build-system = [ hatchling ];
    dependencies = [ ida-domain ];
    meta.license = lib.licenses.mit;
  });

  package = buildPythonPackage (finalAttrs: {
    pname = "ida-mcp";
    version = "20260930.0.1";
    pyproject = true;
    src = fetchPypi {
      pname = "ida_mcp";
      inherit (finalAttrs) version;
      hash = "sha256-MvnHb2FffyxAfQoaZ8YAIRGm/toBT5Zy9H5K/8Qfiw4=";
    };
    build-system = [ hatchling ];
    dependencies = [
      ida-nexus
      python.pkgs.packaging
      zeromcp
    ];

    meta = {
      description = "Official Hex-Rays IDA MCP server";
      homepage = "https://github.com/HexRaysSA/ida-mcp";
      license = lib.licenses.mit;
      mainProgram = "ida-mcp";
    };
  });

  # ida-nexus spawns idalib workers through the ida-nexus script in the running
  # interpreter's bin directory and never searches PATH, so the server has to
  # run from an environment that links both scripts together.
  server = python.withPackages (_: [ package ]);

  plugin = stdenvNoCC.mkDerivation {
    pname = "ida-plugin-ida-mcp";
    inherit (package) version src;

    installPhase = ''
      runHook preInstall
      install -Dm644 ida_mcp_plugin.py "$out/share/ida/plugins/ida_mcp_plugin.py"
      install -Dm644 LICENSE "$out/share/licenses/ida-plugin-ida-mcp/LICENSE"
      runHook postInstall
    '';

    passthru.idaPlugin = {
      pythonPackages = [ package ];
      commands = [ "${server}/bin/ida-mcp" ];
    };

    meta = package.meta // {
      description = "IDA GUI bridge for the official Hex-Rays MCP server";
    };
  };
in
{
  inherit package plugin;
}
