{ pkgs, scope }:
let
  inherit (pkgs) lib;
  fixtureInstaller = pkgs.runCommandCC "ida-fixture-installer" { } ''
    "$CC" ${./fixtures/installer.c} -o "$out"
  '';
  mkFixtureIda =
    args:
    scope.mkIda (
      {
        release = {
          version = "9.2.test";
          systems = [ pkgs.stdenv.hostPlatform.system ];
          license = lib.licenses.mit;
        };
        installer = fixtureInstaller;
        python = pkgs.python314;
      }
      // args
    );
  fixtureCommand = pkgs.writeShellScriptBin "fixture-command" ''
    printf 'IDADIR=%s\n' "$IDADIR"
    printf 'IDAUSR=%s\n' "$IDAUSR"
    printf 'PYTHON=%s\n' "$(command -v python3)"
  '';
  mkFixturePlugin =
    name:
    pkgs.runCommand "ida-plugin-${name}"
      { passthru.idaPlugin.commands = [ (lib.getExe fixtureCommand) ]; }
      ''
        install -Dm644 /dev/null "$out/share/ida/plugins/${name}.py"
      '';
  fixturePlugin = mkFixturePlugin "fixture";
  secondFixturePlugin = mkFixturePlugin "fixture-two";
  fixtureIda = mkFixtureIda {
    plugins = [ fixturePlugin ];
    files = [
      {
        source = ./fixtures/idapro.hexlic;
        target = "idapro.hexlic";
      }
    ];
    hexPatches = [
      {
        filename = "docs/asset with spaces.png";
        from = "00010203";
        to = "04050607";
      }
    ];
  };
  stackedFixtureIda = fixtureIda.withPlugins [ secondFixturePlugin ];
  pythonFixtureIda = mkFixtureIda {
    plugins = [
      scope.plugins.ida-mcp
      scope.plugins.capa-explorer
    ];
  };
in
{
  inherit (scope.plugins) bindiff;

  ida-mcp = pkgs.runCommand "ida-nix-ida-mcp-check" { } ''
    test -x ${dirOf (builtins.head scope.plugins.ida-mcp.idaPlugin.commands)}/ida-nexus
    touch "$out"
  '';

  fixture = pkgs.runCommand "ida-nix-fixture-check" { } ''
    homeRoot="$TMPDIR/home"
    userRoot="$TMPDIR/user"
    mkdir -p "$homeRoot" "$userRoot"
    pluginRoot=${fixturePlugin}/share/ida

    test "$(HOME="$homeRoot" ${fixtureIda}/bin/ida)" = "fixture:$homeRoot/.idapro:$pluginRoot"
    test "$(HOME="$homeRoot" IDAUSR="$userRoot" ${fixtureIda}/bin/ida)" = "fixture:$userRoot:$pluginRoot"
    test "$(HOME="$homeRoot" ${stackedFixtureIda}/bin/ida)" = \
      "fixture:$homeRoot/.idapro:$pluginRoot:${secondFixturePlugin}/share/ida"

    commandOutput="$(HOME="$homeRoot" ${fixtureIda}/bin/fixture-command)"
    grep -Fx "IDADIR=${fixtureIda.ida.root}" <<< "$commandOutput"
    grep -Fx "IDAUSR=$homeRoot/.idapro:$pluginRoot" <<< "$commandOutput"
    grep -E '^PYTHON=.+/bin/python3$' <<< "$commandOutput"

    cmp "${fixtureIda}/opt/ida/docs/asset with spaces.png" \
      <(printf '\004\005\006\007\004\005\006\007')
    grep -Fx fixture ${fixtureIda}/opt/ida/idapro.hexlic
    touch "$out"
  '';

  hex-patch-count =
    let
      failure =
        pkgs.testers.testBuildFailure
          (mkFixtureIda {
            hexPatches = [
              {
                filename = "docs/asset with spaces.png";
                from = "00010203";
                to = "04050607";
                assertCount = 3;
              }
            ];
          }).unwrapped;
    in
    pkgs.runCommand "ida-nix-hex-patch-count-check" { } ''
      grep -F "Expected 3 substitutions, did 2" ${failure}/testBuildFailure.log
      touch "$out"
    '';

  python-environment = pkgs.runCommand "ida-nix-python-environment-check" { } ''
    ${pythonFixtureIda.pythonEnv}/bin/python3 -c 'import capa, ida_mcp, ida_nexus'
    test -x ${pythonFixtureIda}/bin/ida-mcp
    touch "$out"
  '';
}
