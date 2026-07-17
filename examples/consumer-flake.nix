{
  outputs =
    args:
    let
      inputs = (import ./.tack) { overrides = args.tackOverrides or { }; };
      inherit (inputs) ida-nix nixpkgs;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ ida-nix.overlays.default ];
      };
    in
    {
      packages.${system}.default = pkgs.ida-pro.withPlugins [
        pkgs.idaPlugins.bindiff
        pkgs.idaPlugins.ida-pro-mcp
      ];
    };
}
