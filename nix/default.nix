{
  pkgs,
  bindiff,
  bindiffSrc,
}:
let
  inherit (pkgs) lib;
  releases = import ./ida/releases.nix;
  compose = import ./compose.nix { inherit pkgs; };
  inherit (pkgs.stdenv.hostPlatform) system;
  builder = if pkgs.stdenv.hostPlatform.isDarwin then ./ida/darwin.nix else ./ida/linux.nix;
  mkIdaBase = import builder { inherit pkgs; };
  defaultPython = pkgs.${releases.versions.${releases.default}.pythonPackage};

  mkIda =
    {
      version ? releases.default,
      release ? releases.versions.${version},
      installer ?
        let
          entry =
            release.installers.${system}
              or (throw "ida-nix: IDA ${release.version} has no ${system} installer");
          inherit (entry) name;
        in
        pkgs.requireFile {
          inherit (entry) name hash;
          url = "https://my.hex-rays.com/";
          message = ''
            IDA Pro is proprietary and cannot be downloaded by Nix.
            Download ${name} from Hex-Rays, then run:

              nix store add --mode flat --name ${name} ${name}
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

  usable = plugin: lib.meta.availableOn pkgs.stdenv.hostPlatform plugin && !plugin.meta.broken;
  plugins = lib.filterAttrs (_: usable) {
    bindiff = pkgs.callPackage ./plugins/bindiff.nix { inherit bindiff bindiffSrc; };
    ida-mcp = hexRaysMcp.plugin;
    capa-explorer = pkgs.callPackage ./plugins/capa-explorer.nix { python = defaultPython; };
  };
  pick =
    names: lib.attrValues (lib.getAttrs (lib.intersectLists names (lib.attrNames plugins)) plugins);

  ida-pro = mkIda { };
  ida-pro-full = ida-pro.withPlugins (pick [
    "bindiff"
    "ida-mcp"
  ]);
  ida-pro-malware = ida-pro-full.withPlugins (pick [ "capa-explorer" ]);
in
{
  inherit
    compose
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
