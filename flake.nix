{
  description = "Composable Nix packaging for IDA Pro and its plugins";

  outputs =
    args:
    let
      inputs = (import ./.tack) { overrides = args.tackOverrides or { }; };
      inherit (inputs) bindiff ida-pro-mcp nixpkgs;
      inherit (nixpkgs) lib;
      systems = [ "x86_64-linux" ];
      forAllSystems = lib.genAttrs systems;
      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = package: lib.hasPrefix "ida-pro" (lib.getName package);
        };
      mkScope =
        system:
        import ./nix {
          pkgs = mkPkgs system;
          bindiffPackage = bindiff.packages.${system}.bindiff-ida;
          bindiffSrc = bindiff.outPath;
          inherit ida-pro-mcp;
        };
      scopes = forAllSystems mkScope;
    in
    {
      lib = {
        releases = import ./nix/ida/releases.nix;
        forSystem = system: scopes.${system}.lib;
      };

      overlays.default = final: _prev: {
        ida-nix = import ./nix {
          pkgs = final;
          bindiffPackage = bindiff.packages.${final.stdenv.hostPlatform.system}.bindiff-ida;
          bindiffSrc = bindiff.outPath;
          inherit ida-pro-mcp;
        };
        inherit (final.ida-nix) ida-pro ida-pro-unwrapped;
        inherit (final.ida-nix)
          ida-pro-full
          ida-pro-malware
          ida-pro-mcp
          ;
        idaPlugins = final.ida-nix.plugins;
        mkIda = final.ida-nix.mkIda;
        mkIdaPlugin = final.ida-nix.mkIdaPlugin;
      };

      legacyPackages = scopes;

      packages = forAllSystems (
        system:
        let
          scope = scopes.${system};
        in
        {
          default = scope.ida-pro;
          inherit (scope)
            ida-pro
            ida-pro-unwrapped
            ida-pro-full
            ida-pro-malware
            ida-pro-mcp
            ;
          plugin-bindiff = scope.plugins.bindiff;
          plugin-ida-pro-mcp = scope.plugins.ida-pro-mcp;
          plugin-capa-explorer = scope.plugins.capa-explorer;
        }
      );

      checks = forAllSystems (system: import ./tests { scope = scopes.${system}; });

      formatter = forAllSystems (system: (mkPkgs system).nixfmt-tree);

      devShells = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              pkgs.actionlint
              pkgs.deadnix
              pkgs.nixfmt
              pkgs.statix
            ];
          };
        }
      );

      nixosModules.default = import ./nix/nixos-module.nix;
    };
}
