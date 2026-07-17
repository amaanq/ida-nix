{ scope }:
let
  inherit (scope) pkgs;
  inherit (pkgs) lib;
  fixtureInstaller = pkgs.stdenv.mkDerivation {
    pname = "ida-fixture-installer";
    version = "1";
    src = ./fixtures/installer.c;
    dontUnpack = true;
    dontFixup = true;
    installPhase = ''
      "$CC" "$src" -o "$out"
    '';
  };
  fixtureRelease = {
    version = "9.2.test";
    installerName = "fixture.run";
    installerHash = null;
    pythonPackage = "python314";
    pythonAbi = "3.14";
    systems = [ pkgs.stdenv.hostPlatform.system ];
    license = lib.licenses.mit;
  };
  declaredArtifact = {
    root = "plugins";
    path = "declared.py";
  };
  fixtureCommand = pkgs.writeShellScript "ida-fixture-command" ''
    printf 'IDADIR=%s\n' "$IDADIR"
    printf 'IDAUSR=%s\n' "$IDAUSR"
    printf 'PYTHONPATH=%s\n' "$PYTHONPATH"
    printf 'QT_PLUGIN_PATH=%s\n' "$QT_PLUGIN_PATH"
    printf 'LD_LIBRARY_PATH=%s\n' "$LD_LIBRARY_PATH"
    printf 'PYTHON=%s\n' "$(command -v python3)"
  '';
  mkFixturePlugin =
    {
      id,
      path ? "${id}.py",
      root ? "plugins",
      entrypoint ? true,
      commands ? [ ],
      idaVersions ? {
        min = "9.2";
        maxExclusive = "9.3";
      },
      pythonAbi ? "3.14",
      conflicts ? [ ],
      requires ? [ ],
      runtimePackages ? [ ],
    }:
    scope.mkIdaPlugin {
      inherit
        commands
        conflicts
        id
        idaVersions
        pythonAbi
        requires
        runtimePackages
        ;
      version = "1";
      src = ./fixtures;
      artifacts = [
        {
          inherit entrypoint path root;
        }
      ];
      installPhase = ''
        install -Dm644 /dev/null "$out/share/ida/${root}/${path}"
        ${lib.concatMapStringsSep "\n" (command: ''
          install -Dm755 "${fixtureCommand}" "$out/bin/${command}"
        '') commands}
      '';
    };
  fixturePlugin = mkFixturePlugin {
    id = "fixture";
    path = "fixture.py";
    commands = [ "fixture-command" ];
  };
  secondFixturePlugin = mkFixturePlugin {
    id = "fixture-two";
    path = "fixture_two.py";
  };
  nestedFixturePlugin = mkFixturePlugin {
    id = "nested-fixture";
    root = "til";
    path = "arm/fixture.til";
  };
  checkSuppressionEscapePlugin = scope.mkIdaPlugin {
    id = "check-suppression-escape";
    version = "1";
    src = ./fixtures;
    artifacts = [ declaredArtifact ];
    doInstallCheck = false;
    installPhase = ''
      install -Dm644 /dev/null \
        "$out/share/ida/${declaredArtifact.root}/${declaredArtifact.path}"
      touch "$out/share/ida/${declaredArtifact.root}/undeclared.py"
    '';
  };
  runtimeShadowPackage = pkgs.writeShellScriptBin "fixture-command" ''
    echo shadowed
  '';
  runtimeShadowPlugin = mkFixturePlugin {
    id = "runtime-shadow";
    path = "runtime_shadow.py";
    runtimePackages = [ runtimeShadowPackage ];
  };
  inventoryEscapePlugin = scope.mkIdaPlugin {
    id = "inventory-escape";
    version = "1";
    src = ./fixtures;
    artifacts = [ declaredArtifact ];
    phases = [ "installPhase" ];
    installPhase = ''
      install -Dm644 /dev/null \
        "$out/share/ida/${declaredArtifact.root}/${declaredArtifact.path}"
      touch "$out/share/ida/${declaredArtifact.root}/undeclared.py"
      installCheckPhase=true
    '';
  };
  buildCommandEscapePlugin = scope.mkIdaPlugin {
    id = "build-command-escape";
    version = "1";
    src = ./fixtures;
    artifacts = [ declaredArtifact ];
    installPhase = "false";
    buildCommand = ''
      mkdir -p "$out/share/ida/${declaredArtifact.root}"
      touch "$out/share/ida/${declaredArtifact.root}/${declaredArtifact.path}"
      touch "$out/share/ida/${declaredArtifact.root}/undeclared.py"
    '';
  };
  argsEscapePlugin = scope.mkIdaPlugin {
    id = "args-escape";
    version = "1";
    src = ./fixtures;
    artifacts = [ declaredArtifact ];
    installPhase = "false";
    args = [
      "-c"
      ''
        ${pkgs.coreutils}/bin/mkdir -p "$out/share/ida/${declaredArtifact.root}"
        ${pkgs.coreutils}/bin/touch \
          "$out/share/ida/${declaredArtifact.root}/${declaredArtifact.path}"
        ${pkgs.coreutils}/bin/touch "$out/share/ida/${declaredArtifact.root}/undeclared.py"
      ''
    ];
  };
  directorySymlinkPlugin = scope.mkIdaPlugin {
    id = "directory-symlink";
    version = "1";
    src = ./fixtures;
    artifacts = [
      {
        root = "plugins";
        path = "bundle";
      }
    ];
    installPhase = ''
      mkdir -p "$out/share/ida/plugins" "$out/share/hidden"
      touch "$out/share/hidden/undeclared.py"
      ln -s "$out/share/hidden" "$out/share/ida/plugins/bundle"
    '';
  };
  mutableSymlinkPlugin = scope.mkIdaPlugin {
    id = "mutable-symlink";
    version = "1";
    src = ./fixtures;
    artifacts = [
      {
        root = "plugins";
        path = "mutable.py";
      }
    ];
    installPhase = ''
      mkdir -p "$out/share/ida/plugins"
      ln -s /tmp/ida-nix-mutable-target "$out/share/ida/plugins/mutable.py"
    '';
  };
  undeclaredCommandPlugin = scope.mkIdaPlugin {
    id = "undeclared-command";
    version = "1";
    src = ./fixtures;
    artifacts = [ declaredArtifact ];
    installPhase = ''
      install -Dm644 /dev/null \
        "$out/share/ida/${declaredArtifact.root}/${declaredArtifact.path}"
      install -Dm755 "${fixtureCommand}" "$out/bin/shadowed-command"
    '';
  };
  newlineArtifactPlugin = scope.mkIdaPlugin {
    id = "newline-artifact";
    version = "1";
    src = ./fixtures;
    artifacts = [
      {
        root = "plugins";
        path = "one.py";
      }
      {
        root = "plugins";
        path = "two.py";
      }
    ];
    installPhase = ''
      newlineDirectory="$out/share/ida/plugins/one.py"$'\n'plugins
      mkdir -p "$newlineDirectory"
      touch "$newlineDirectory/two.py"
    '';
  };
  newlineCommandPlugin = scope.mkIdaPlugin {
    id = "newline-command";
    version = "1";
    src = ./fixtures;
    artifacts = [ declaredArtifact ];
    commands = [
      "one"
      "two"
    ];
    installPhase = ''
      install -Dm644 /dev/null \
        "$out/share/ida/${declaredArtifact.root}/${declaredArtifact.path}"
      install -Dm755 "${fixtureCommand}" "$out/bin/one"
      install -Dm755 "${fixtureCommand}" "$out/bin/two"
      newlineDirectory="$out/bin/one"$'\n'bin
      mkdir -p "$newlineDirectory"
      install -Dm755 "${fixtureCommand}" "$newlineDirectory/two"
    '';
  };
  expectBuildFailure =
    name: message: package:
    let
      failure = pkgs.testers.testBuildFailure package;
    in
    pkgs.runCommand "ida-nix-${name}" { } ''
      grep -F ${lib.escapeShellArg message} "${failure}/testBuildFailure.log"
      touch "$out"
    '';
  fixtureBase = scope.mkIda {
    inherit (fixtureRelease) version;
    installer = fixtureInstaller;
    python = pkgs.python314;
    plugins = [ ];
    release = fixtureRelease;
  };
  fixtureIda = fixtureBase.withPlugins [ fixturePlugin ];
  stackedFixtureIda = fixtureIda.withPlugins [ secondFixturePlugin ];
  commandOwnershipIda = fixtureBase.withPlugins [
    runtimeShadowPlugin
    fixturePlugin
  ];
  pythonFixtureIda = fixtureBase.withPlugins [
    scope.plugins.ida-pro-mcp
    scope.plugins.capa-explorer
  ];
  bindiffFixtureIda = fixtureBase.withPlugins [ scope.plugins.bindiff ];
  overriddenFixturePlugin = fixturePlugin.overrideAttrs {
    pname = "overridden-fixture";
  };

  tryCompose = plugins: builtins.tryEval (fixtureBase.withPlugins plugins).drvPath;
  tryPluginDefinition =
    attrs:
    builtins.tryEval
      (scope.mkIdaPlugin (
        {
          version = "1";
          src = ./fixtures;
          artifacts = [ declaredArtifact ];
          installPhase = "touch $out";
        }
        // attrs
      )).drvPath;
  guardrailCases = {
    accepted = {
      valid = tryCompose [
        fixturePlugin
        secondFixturePlugin
        nestedFixturePlugin
      ];
      distinctNamespace = tryCompose [
        fixturePlugin
        (mkFixturePlugin {
          id = "loader-fixture";
          root = "loaders";
          path = "fixture.py";
        })
      ];
      satisfiedRequirement = tryCompose [
        fixturePlugin
        (mkFixturePlugin {
          id = "dependent";
          requires = [ "fixture" ];
        })
      ];
    };
    rejected = {
      duplicateId = tryCompose [
        fixturePlugin
        fixturePlugin
      ];
      duplicateEntrypoint = tryCompose [
        fixturePlugin
        (mkFixturePlugin {
          id = "duplicate-entrypoint";
          path = "fixture.so";
        })
      ];
      caseExtensionCollision = tryCompose [
        fixturePlugin
        (mkFixturePlugin {
          id = "case-extension-collision";
          path = "Fixture.so";
        })
      ];
      missingRequirement = tryCompose [
        (mkFixturePlugin {
          id = "orphan";
          requires = [ "fixture" ];
        })
      ];
      conflict = tryCompose [
        fixturePlugin
        (mkFixturePlugin {
          id = "conflict";
          conflicts = [ "fixture" ];
        })
      ];
      duplicateCommand = tryCompose [
        fixturePlugin
        (mkFixturePlugin {
          id = "duplicate-command";
          commands = [ "fixture-command" ];
        })
      ];
      incompatibleVersion = tryCompose [
        (mkFixturePlugin {
          id = "future";
          idaVersions.min = "9.3";
        })
      ];
      pythonAbiMismatch = tryCompose [
        (mkFixturePlugin {
          id = "wrong-python";
          pythonAbi = "3.13";
        })
      ];
      overriddenPlugin = tryCompose [ overriddenFixturePlugin ];
      reservedCommand = tryPluginDefinition {
        id = "reserved-command";
        commands = [ "ida" ];
      };
      invalidArtifactRoot = tryPluginDefinition {
        id = "invalid-root";
        artifacts = [
          {
            root = "../plugins";
            path = "invalid.py";
          }
        ];
      };
      invalidArtifactPath = tryPluginDefinition {
        id = "invalid-path";
        artifacts = [
          {
            root = "plugins";
            path = "../invalid.py";
          }
        ];
      };
      invalidCommand = tryPluginDefinition {
        id = "invalid-command";
        commands = [ ".." ];
      };
      invalidCommandPath = tryPluginDefinition {
        id = "invalid-command-path";
        commands = [
          {
            name = "safe-name";
            path = "../escape";
          }
        ];
      };
      unknownArtifactAttr = tryPluginDefinition {
        id = "unknown-artifact-attr";
        artifacts = [ (declaredArtifact // { unknown = true; }) ];
      };
      unknownCommandAttr = tryPluginDefinition {
        id = "unknown-command-attr";
        commands = [
          {
            name = "safe-name";
            unknown = true;
          }
        ];
      };
      invalidVersionRange = tryPluginDefinition {
        id = "invalid-range";
        idaVersions = {
          min = "9.3";
          maxExclusive = "9.2";
        };
      };
      invalidVersionKey = tryPluginDefinition {
        id = "invalid-version-key";
        idaVersions = {
          min = "9.2";
          maxExlusive = "9.3";
        };
      };
      mislabelledEntrypoint = tryPluginDefinition {
        id = "mislabelled-entrypoint";
        artifacts = [
          {
            root = "plugins";
            path = "invalid.py";
            entrypoint = false;
          }
        ];
      };
      overlappingRequirement = tryPluginDefinition {
        id = "overlapping-requirement";
        conflicts = [ "fixture" ];
        requires = [ "fixture" ];
      };
    };
  };
  unexpectedGuardrailFailures = lib.attrNames (
    lib.filterAttrs (_: result: !result.success) guardrailCases.accepted
  );
  unexpectedGuardrailSuccesses = lib.attrNames (
    lib.filterAttrs (_: result: result.success) guardrailCases.rejected
  );

  nixosEvaluation = lib.evalModules {
    specialArgs = { inherit pkgs; };
    modules = [
      {
        options.environment.systemPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
        };
      }
      ../nix/nixos-module.nix
      {
        programs.ida-pro = {
          enable = true;
          package = fixtureBase;
          plugins = [ fixturePlugin ];
        };
      }
    ];
  };
in
{
  api =
    assert scope.lib.isIdaPlugin fixturePlugin;
    assert fixtureIda.version == fixtureRelease.version;
    assert fixtureIda.pluginIds == [ "fixture" ];
    assert
      stackedFixtureIda.pluginIds == [
        "fixture"
        "fixture-two"
      ];
    assert checkSuppressionEscapePlugin.drvAttrs.doInstallCheck;
    pkgs.runCommand "ida-nix-api-check" { } ''
      test -f "${fixturePlugin}/share/ida/plugins/fixture.py"
      test -f "${nestedFixturePlugin}/share/ida/til/arm/fixture.til"
      test "${builtins.concatStringsSep "," fixtureIda.pluginIds}" = "fixture"
      touch "$out"
    '';

  synthetic-installer = pkgs.runCommand "ida-nix-synthetic-installer-check" { } ''
    homeRoot="$TMPDIR/home"
    userRoot="$TMPDIR/user"
    mkdir -p "$homeRoot" "$userRoot"

    output="$(HOME="$homeRoot" ${fixtureIda}/bin/ida)"
    test "$output" = "fixture:$homeRoot/.idapro:${fixturePlugin}/share/ida"

    output="$(HOME="$homeRoot" IDAUSR="$userRoot" ${fixtureIda}/bin/ida)"
    test "$output" = "fixture:$userRoot:${fixturePlugin}/share/ida"

    output="$(HOME="$homeRoot" ${stackedFixtureIda}/bin/ida)"
    test "$output" = \
      "fixture:$homeRoot/.idapro:${fixturePlugin}/share/ida:${secondFixturePlugin}/share/ida"

    commandOutput="$(HOME="$homeRoot" ${fixtureIda}/bin/fixture-command)"
    grep -Fx "IDADIR=${fixtureIda.ida.root}" <<< "$commandOutput"
    grep -Fx "IDAUSR=$homeRoot/.idapro:${fixturePlugin}/share/ida" <<< "$commandOutput"
    grep -E '^PYTHONPATH=.+$' <<< "$commandOutput"
    grep -E '^QT_PLUGIN_PATH=.+$' <<< "$commandOutput"
    grep -E '^LD_LIBRARY_PATH=.+$' <<< "$commandOutput"
    grep -E '^PYTHON=.+/bin/python3$' <<< "$commandOutput"

    ownedCommandOutput="$(HOME="$homeRoot" ${commandOwnershipIda}/bin/fixture-command)"
    grep -Fx "IDADIR=${commandOwnershipIda.ida.root}" <<< "$ownedCommandOutput"
    if grep -Fx shadowed <<< "$ownedCommandOutput"; then
      echo "runtime package shadowed the declared command owner" >&2
      exit 1
    fi
    touch "$out"
  '';

  profile-layout = pkgs.runCommand "ida-nix-profile-layout-check" { } ''
    test -L "${fixtureIda}/lib"
    test -L "${fixtureIda}/opt"
    test -L "${fixtureIda}/share"
    test -f "${fixtureIda}/opt/ida/docs/asset with spaces.png"

    if find "${fixtureIda}" -mindepth 2 -type l -print -quit | grep -q .; then
      echo "composed profiles must not expand the base package into a symlink forest" >&2
      exit 1
    fi

    touch "$out"
  '';

  guardrails =
    assert lib.assertMsg (unexpectedGuardrailFailures == [ ])
      "ida-nix: expected guardrail cases failed: ${lib.concatStringsSep ", " unexpectedGuardrailFailures}";
    assert lib.assertMsg (unexpectedGuardrailSuccesses == [ ])
      "ida-nix: rejected guardrail cases unexpectedly succeeded: ${lib.concatStringsSep ", " unexpectedGuardrailSuccesses}";
    pkgs.runCommand "ida-nix-guardrail-check" { } ''
      touch "$out"
    '';

  inventory-escape-rejected =
    expectBuildFailure "inventory-escape-rejected"
      "installed IDA artifacts differ from the declared inventory"
      inventoryEscapePlugin;

  check-suppression-escape-rejected =
    expectBuildFailure "check-suppression-escape-rejected"
      "installed IDA artifacts differ from the declared inventory"
      checkSuppressionEscapePlugin;

  build-command-escape-rejected =
    expectBuildFailure "build-command-escape-rejected"
      "installed IDA artifacts differ from the declared inventory"
      buildCommandEscapePlugin;

  args-escape-rejected =
    expectBuildFailure "args-escape-rejected"
      "installed IDA artifacts differ from the declared inventory"
      argsEscapePlugin;

  directory-symlink-rejected =
    expectBuildFailure "directory-symlink-rejected"
      "artifact symlink must resolve to an immutable regular file"
      directorySymlinkPlugin;

  mutable-symlink-rejected =
    expectBuildFailure "mutable-symlink-rejected"
      "artifact symlink must resolve to an immutable regular file"
      mutableSymlinkPlugin;

  undeclared-command-rejected =
    expectBuildFailure "undeclared-command-rejected"
      "installed plugin commands differ from the declared inventory"
      undeclaredCommandPlugin;

  newline-artifact-rejected =
    expectBuildFailure "newline-artifact-rejected" "inventoried paths cannot contain newlines"
      newlineArtifactPlugin;

  newline-command-rejected =
    expectBuildFailure "newline-command-rejected" "inventoried paths cannot contain newlines"
      newlineCommandPlugin;

  modules =
    assert (builtins.head nixosEvaluation.config.environment.systemPackages).pluginIds == [ "fixture" ];
    pkgs.runCommand "ida-nix-module-check" { } ''
      touch "$out"
    '';

  python-environment = pkgs.runCommand "ida-nix-python-environment-check" { } ''
    ${pythonFixtureIda.pythonEnv}/bin/python3 -c 'import capa, ida_pro_mcp'
    ${pythonFixtureIda.pythonEnv}/bin/python3 -c 'import importlib.util; assert importlib.util.find_spec("ida_mcp")'
    touch "$out"
  '';

  mcp-layout =
    assert scope.ida-pro-mcp.meta.mainProgram == "ida-pro-mcp";
    assert scope.plugins.ida-pro-mcp.idaPlugin.requiresDecompiler;
    assert
      pythonFixtureIda.commands == [
        "ida-pro-mcp"
        "idalib-mcp"
      ];
    pkgs.runCommand "ida-nix-mcp-layout-check" { } ''
      test -f "${scope.plugins.ida-pro-mcp}/share/ida/plugins/ida_pro_mcp.py"
      test -f "${scope.plugins.ida-pro-mcp}/share/licenses/ida-plugin-ida-pro-mcp/LICENSE"
      test -f "${scope.ida-pro-mcp}/share/licenses/ida-pro-mcp/LICENSE"
      test -x "${scope.ida-pro-mcp}/bin/ida-pro-mcp"
      test -x "${scope.ida-pro-mcp}/bin/idalib-mcp"
      test -x "${pythonFixtureIda}/bin/ida-pro-mcp"
      test -x "${pythonFixtureIda}/bin/idalib-mcp"
      helpOutput="$(${scope.ida-pro-mcp}/bin/ida-pro-mcp --help 2>&1)"
      case "$helpOutput" in
        *"Failed to generate code"*)
          echo "$helpOutput" >&2
          exit 1
          ;;
      esac
      touch "$out"
    '';

  bindiff-layout = pkgs.runCommand "ida-nix-bindiff-layout-check" { } ''
    test -f "${scope.plugins.bindiff}/share/ida/plugins/bindiff8_ida64.so"
    test -f "${scope.plugins.bindiff}/share/ida/plugins/binexport12_ida64.so"
    test -f "${scope.plugins.bindiff}/share/licenses/ida-plugin-bindiff/LICENSE"
    test -x "${bindiffFixtureIda}/bin/bindiff"
    touch "$out"
  '';

  capa-layout =
    assert !(scope.plugins.capa-explorer.meta ? mainProgram);
    pkgs.runCommand "ida-nix-capa-layout-check" { } ''
      test -f "${scope.plugins.capa-explorer}/share/ida/plugins/capa_explorer.py"
      test -f "${scope.plugins.capa-explorer}/share/ida/plugins/capa-explorer.json"
      touch "$out"
    '';
}
