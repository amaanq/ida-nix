{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.ida-pro;
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
      description = "IDA plugin packages to compose with the base package.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ (cfg.package.withPlugins cfg.plugins) ];
  };
}
