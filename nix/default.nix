{
  pkgs,
  bindiff,
  bindiffSrc,
}:
let
  releases = import ./ida/releases.nix;
  compose = import ./compose.nix { inherit pkgs; };
  mkIdaBase = import ./ida/package.nix { inherit pkgs; };
  defaultPython = pkgs.${releases.versions.${releases.default}.pythonPackage};

  mkIda =
    {
      version ? releases.default,
      release ? releases.versions.${version},
      installer ? pkgs.requireFile {
        name = release.installerName;
        hash = release.installerHash;
        url = "https://my.hex-rays.com/";
        message = ''
          IDA Pro is proprietary and cannot be downloaded by Nix.
          Download ${release.installerName} from Hex-Rays, then run:

            nix store add --mode flat --name ${release.installerName} ${release.installerName}
        '';
      },
      python ? pkgs.${release.pythonPackage},
      plugins ? [ ],
      files ? [ ],
      hexPatches ? [ ],
      extraRuntimeDependencies ? [ ],
    }:
    compose (mkIdaBase {
      inherit
        release
        python
        installer
        files
        hexPatches
        extraRuntimeDependencies
        ;
    }) plugins;

  hexRaysMcp = pkgs.callPackage ./plugins/ida-mcp.nix { python = defaultPython; };

  plugins = {
    bindiff = pkgs.callPackage ./plugins/bindiff.nix { inherit bindiff bindiffSrc; };
    ida-mcp = hexRaysMcp.plugin;
    capa-explorer = pkgs.callPackage ./plugins/capa-explorer.nix { python = defaultPython; };
  };

  ida-pro = mkIda { };
  ida-pro-full = ida-pro.withPlugins [
    plugins.bindiff
    plugins.ida-mcp
  ];
  ida-pro-malware = ida-pro-full.withPlugins [ plugins.capa-explorer ];
in
{
  inherit
    ida-pro
    ida-pro-full
    ida-pro-malware
    mkIda
    plugins
    releases
    ;
  ida-pro-unwrapped = ida-pro.unwrapped;
  ida-mcp = hexRaysMcp.package;
}
