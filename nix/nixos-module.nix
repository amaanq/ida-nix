{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.ida-pro;
  package =
    if cfg.plugins == [ ] then
      cfg.package
    else if cfg.package ? withPlugins then
      cfg.package.withPlugins cfg.plugins
    else
      throw "programs.ida-pro.package does not support withPlugins";
in
{
  options.programs.ida-pro = {
    enable = lib.mkEnableOption "IDA Pro";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ida-pro;
      defaultText = lib.literalExpression "pkgs.ida-pro";
      description = "IDA package to install.";
    };
    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.idaPlugins.bindiff ]";
      description = "Typed IDA plugin packages to compose with the base package.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ package ];
  };
}
