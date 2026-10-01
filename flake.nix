{
  description = "Composable Nix packaging for IDA Pro and its plugins";

  outputs =
    args:
    let
      inputs = (import ./.tack) { overrides = args.tackOverrides or { }; };
      inherit (inputs) bindiff nixpkgs;
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs [ "x86_64-linux" ];
      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = package: lib.hasPrefix "ida-pro" (lib.getName package);
        };
      mkScope =
        pkgs:
        import ./nix {
          inherit pkgs;
          bindiff = bindiff.packages.${pkgs.stdenv.hostPlatform.system}.bindiff-ida;
          bindiffSrc = bindiff.outPath;
        };
      scopes = forAllSystems (system: mkScope (mkPkgs system));
    in
    {
      lib = {
        releases = import ./nix/ida/releases.nix;
        inherit (import ./nix/hex-patches.nix { inherit lib; }) mkHexPatcher;
      };

      overlays.default =
        final: _prev:
        let
          scope = mkScope final;
        in
        {
          ida-nix = scope;
          inherit (scope)
            ida-pro
            ida-pro-unwrapped
            ida-pro-full
            ida-pro-malware
            ida-mcp
            mkIda
            ;
          idaPlugins = scope.plugins;
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
            ida-mcp
            ;
        }
        // lib.mapAttrs' (name: lib.nameValuePair "plugin-${name}") scope.plugins
      );

      checks = forAllSystems (
        system:
        import ./tests {
          pkgs = mkPkgs system;
          scope = scopes.${system};
        }
      );

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
