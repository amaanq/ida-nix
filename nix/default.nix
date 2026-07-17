{
  pkgs,
  bindiffPackage,
  bindiffSrc,
  ida-pro-mcp,
}:
let
  inherit (pkgs) lib;
  releases = import ./ida/releases.nix;
  pluginLib = import ./plugin-lib.nix { inherit pkgs; };
  mkIdaBase = import ./ida/package.nix { inherit pkgs; };
  defaultRelease = releases.versions.${releases.default};
  defaultPython = pkgs.${defaultRelease.pythonPackage};

  installerFor =
    release: installer:
    if installer != null then
      installer
    else if (release.installerHash or null) != null then
      pkgs.requireFile {
        name = release.installerName;
        hash = release.installerHash;
        url = "https://my.hex-rays.com/";
        message = ''
          IDA Pro is proprietary and cannot be downloaded by Nix.
          Download ${release.installerName} from Hex-Rays, then run:

            nix store add --mode flat --name ${release.installerName} ${release.installerName}
        '';
      }
    else
      throw "ida-nix: release ${release.version} needs an explicit installer path";

  buildIdaBase =
    {
      release,
      resolvedPython,
      installer ? null,
      extraRuntimeDependencies ? [ ],
    }:
    mkIdaBase {
      inherit extraRuntimeDependencies release resolvedPython;
      source = installerFor release installer;
    };

  mkIda =
    {
      version ? releases.default,
      installer ? null,
      release ? releases.versions.${version} or null,
      python ? null,
      plugins ? [ ],
      extraRuntimeDependencies ? [ ],
    }:
    let
      resolvedRelease =
        if release != null then
          release
        else if installer != null && python != null then
          {
            inherit version;
            installerName = baseNameOf installer;
            installerHash = null;
            pythonPackage = null;
            pythonAbi = python.pythonVersion or (lib.versions.majorMinor python.version);
            systems = [ pkgs.stdenv.hostPlatform.system ];
          }
        else
          throw "ida-nix: unknown IDA release ${version}; pass both installer and python, or add release metadata";
      resolvedPython =
        if python != null then
          python
        else if (resolvedRelease.pythonPackage or null) != null then
          pkgs.${resolvedRelease.pythonPackage}
        else
          throw "ida-nix: release ${version} needs an explicit Python interpreter";
      resolvedPythonAbi =
        resolvedPython.pythonVersion or (lib.versions.majorMinor resolvedPython.version);
      base = buildIdaBase {
        inherit extraRuntimeDependencies installer resolvedPython;
        release = resolvedRelease;
      };
    in
    assert lib.assertMsg (
      resolvedRelease.version == version
    ) "ida-nix: requested version ${version} does not match release ${resolvedRelease.version}";
    assert lib.assertMsg (builtins.elem pkgs.stdenv.hostPlatform.system resolvedRelease.systems)
      "ida-nix: IDA ${resolvedRelease.version} does not support ${pkgs.stdenv.hostPlatform.system}";
    assert lib.assertMsg (resolvedPythonAbi == resolvedRelease.pythonAbi)
      "ida-nix: IDA ${resolvedRelease.version} requires Python ${resolvedRelease.pythonAbi}, got ${resolvedPythonAbi}";
    pluginLib.compose {
      ida = base;
      inherit plugins;
    };

  ida-pro-unwrapped = buildIdaBase {
    release = defaultRelease;
    resolvedPython = defaultPython;
  };

  mcp = import ./plugins/ida-pro-mcp.nix {
    src = ida-pro-mcp;
    inherit (pluginLib) mkIdaPlugin;
    python = defaultPython;
  };

  plugins = {
    bindiff = import ./plugins/bindiff.nix {
      inherit bindiffPackage bindiffSrc;
      inherit (pluginLib) mkIdaPlugin;
    };

    ida-pro-mcp = mcp.plugin;

    capa-explorer = import ./plugins/capa-explorer.nix {
      inherit (pluginLib) mkIdaPlugin;
      python = defaultPython;
    };
  };

  ida-pro = pluginLib.compose {
    ida = ida-pro-unwrapped;
    plugins = [ ];
  };

  ida-pro-full = ida-pro.withPlugins [
    plugins.bindiff
    plugins.ida-pro-mcp
  ];

  ida-pro-malware = ida-pro-full.withPlugins [ plugins.capa-explorer ];
in
{
  inherit
    ida-pro
    ida-pro-full
    ida-pro-malware
    ida-pro-unwrapped
    mkIda
    plugins
    pkgs
    releases
    ;

  ida-pro-mcp = mcp.package;

  inherit (pluginLib) mkIdaPlugin;

  lib = {
    inherit (pluginLib)
      compose
      isIdaPlugin
      mkIdaPlugin
      pluginMetadata
      ;
    inherit mkIda releases;
  };
}
