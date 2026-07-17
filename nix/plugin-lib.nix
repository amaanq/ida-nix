{ pkgs }:
let
  inherit (pkgs) lib;
  contractVersion = 1;
  contractMarker = pkgs.writeText "ida-plugin-contract-v${toString contractVersion}" ''
    ida-nix validated plugin contract version ${toString contractVersion}
  '';
  allowedArtifactRoots = [
    "cfg"
    "idc"
    "ids"
    "loaders"
    "plugins"
    "procs"
    "sig"
    "themes"
    "til"
  ];
  discoveryArtifactRoots = [
    "loaders"
    "plugins"
    "procs"
  ];
  reservedCommands = [
    "ida"
    "idat"
  ];
  # Contract metadata must never leak into the caller-controlled payload.
  contractArgNames = [
    "artifacts"
    "commands"
    "conflicts"
    "id"
    "idaVersions"
    "pythonAbi"
    "pythonPackages"
    "requires"
    "requiresDecompiler"
    "runtimePackages"
  ];
  safeRelativePath = "[A-Za-z0-9][A-Za-z0-9._+-]*(/[A-Za-z0-9][A-Za-z0-9._+-]*)*";
  validPluginId =
    value: builtins.isString value && builtins.match "[a-z0-9][a-z0-9._-]*" value != null;
  validCommandName =
    value: builtins.isString value && builtins.match "[A-Za-z0-9][A-Za-z0-9._+-]*" value != null;
  hasOnlyAttrs =
    allowed: value:
    builtins.isAttrs value && lib.all (name: builtins.elem name allowed) (builtins.attrNames value);
  renderInventory =
    paths:
    lib.optionalString (paths != [ ]) (
      lib.concatStringsSep "\n" (lib.sort builtins.lessThan paths) + "\n"
    );

  artifactPath = artifact: "${artifact.root}/${artifact.path}";

  normalizeArtifact = artifact: {
    inherit (artifact) path root;
    entrypoint = artifact.entrypoint or true;
  };

  inferredEntrypoint =
    artifact:
    builtins.elem artifact.root discoveryArtifactRoots
    && (
      lib.hasSuffix ".py" (lib.toLower artifact.path) || lib.hasSuffix ".so" (lib.toLower artifact.path)
    );

  normalizeCommand =
    command:
    if builtins.isString command then
      {
        name = command;
        package = null;
        path = "bin/${command}";
      }
    else
      {
        inherit (command) name;
        package = command.package or null;
        path = command.path or "bin/${command.name}";
      };

  validCommand =
    command:
    if builtins.isString command then
      validCommandName command
    else
      let
        path = command.path or "bin/${command.name}";
      in
      hasOnlyAttrs [
        "name"
        "package"
        "path"
      ] command
      && command ? name
      && validCommandName command.name
      && builtins.isString path
      && builtins.match safeRelativePath path != null
      && ((command.package or null) == null || lib.isDerivation command.package);

  entrypointCollisionKey =
    artifact:
    let
      extensionMatch = builtins.match "(.*)\\.[^./]+" artifact.path;
      stem = if extensionMatch == null then artifact.path else builtins.head extensionMatch;
    in
    "${artifact.root}/${lib.toLower stem}";

  validArtifact =
    artifact:
    hasOnlyAttrs [
      "entrypoint"
      "path"
      "root"
    ] artifact
    && artifact ? root
    && builtins.isString artifact.root
    && builtins.elem artifact.root allowedArtifactRoots
    && artifact ? path
    && builtins.isString artifact.path
    && builtins.match safeRelativePath artifact.path != null
    && builtins.isBool (artifact.entrypoint or true)
    && ((artifact.entrypoint or true) || !inferredEntrypoint artifact);

  isIdaPlugin =
    plugin:
    lib.isDerivation plugin
    && plugin ? idaPlugin
    && builtins.isAttrs plugin.idaPlugin
    && (plugin.idaPlugin.contractMarker or null) == contractMarker
    && (plugin.idaPlugin.contractVersion or null) == contractVersion
    && (plugin.idaPlugin.root or null) == "${plugin}/share/ida";

  pluginMetadata =
    plugin:
    if isIdaPlugin plugin then
      plugin.idaPlugin
    else
      throw "ida-nix: value does not implement the idaPlugin contract";

  mkIdaPlugin =
    args@{
      id,
      version,
      artifacts,
      installPhase,
      commands ? [ ],
      idaVersions ? { },
      pythonAbi ? null,
      pythonPackages ? [ ],
      runtimePackages ? [ ],
      conflicts ? [ ],
      requires ? [ ],
      requiresDecompiler ? false,
      ...
    }:
    let
      artifactsValid = builtins.isList artifacts && artifacts != [ ] && lib.all validArtifact artifacts;
      normalizedArtifacts = if artifactsValid then map normalizeArtifact artifacts else [ ];
      artifactPaths = map artifactPath normalizedArtifacts;
      commandsValid = builtins.isList commands && lib.all validCommand commands;
      normalizedCommands = if commandsValid then map normalizeCommand commands else [ ];
      commandNames = map (command: command.name) normalizedCommands;
      selfCommandPaths = map (command: command.path) (
        lib.filter (
          command: command.package == null && lib.hasPrefix "bin/" command.path
        ) normalizedCommands
      );
      artifactRoots = lib.unique (map (artifact: artifact.root) normalizedArtifacts);
      entrypointArtifacts = lib.filter (artifact: artifact.entrypoint) normalizedArtifacts;
      entrypoints = map artifactPath entrypointArtifacts;
      entrypointCollisionKeys = map entrypointCollisionKey entrypointArtifacts;
      expectedArtifacts = pkgs.writeText "ida-plugin-${id}-artifacts" (renderInventory artifactPaths);
      expectedCommands = pkgs.writeText "ida-plugin-${id}-commands" (renderInventory selfCommandPaths);
      commandChecks = lib.concatMapStringsSep "\n" (
        command:
        let
          provider = if command.package == null then "$out" else toString command.package;
        in
        /* sh */ ''
          commandTarget="${provider}/${command.path}"
          resolvedCommandTarget="$(readlink -f "$commandTarget")" || {
            echo "ida-nix: declared plugin command does not resolve: ${command.name}" >&2
            exit 1
          }
          case "$resolvedCommandTarget" in
            "${builtins.storeDir}/"*) ;;
            *)
              echo "ida-nix: declared plugin command is not immutable: ${command.name}" >&2
              exit 1
              ;;
          esac
          if [ ! -f "$resolvedCommandTarget" ] || [ ! -x "$commandTarget" ]; then
            echo "ida-nix: declared plugin command is not executable: ${command.name}" >&2
            exit 1
          fi
        ''
      ) normalizedCommands;
      minimumIdaVersion = if builtins.isAttrs idaVersions then idaVersions.min or null else null;
      maximumIdaVersion = if builtins.isAttrs idaVersions then idaVersions.maxExclusive or null else null;
      validVersionRange =
        hasOnlyAttrs [
          "maxExclusive"
          "min"
        ] idaVersions
        && (minimumIdaVersion == null || builtins.isString minimumIdaVersion)
        && (maximumIdaVersion == null || builtins.isString maximumIdaVersion)
        && (
          minimumIdaVersion == null
          || maximumIdaVersion == null
          || lib.versionOlder minimumIdaVersion maximumIdaVersion
        );
      derivationArgs = removeAttrs args contractArgNames;
      payload = pkgs.stdenvNoCC.mkDerivation (
        derivationArgs
        // {
          pname = args.pname or "ida-plugin-${id}";
          inherit installPhase;
          dontBuild = args.dontBuild or true;
        }
      );
      # The outer derivation owns validation so payload phases and raw
      # mkDerivation arguments cannot replace the contract checks.
      drv = pkgs.stdenvNoCC.mkDerivation {
        pname = args.pname or "ida-plugin-${id}";
        inherit version;
        dontUnpack = true;
        dontBuild = true;
        dontFixup = true;
        phases = [
          "installPhase"
          "installCheckPhase"
        ];
        installPhase = ''
          mkdir -p "$out"
          cp -a "${payload}/." "$out/"
          chmod u+w "$out"
        '';
        doInstallCheck = true;
        installCheckPhase = ''
          for inventoryRoot in "$out/share/ida" "$out/bin"; do
            if [ ! -d "$inventoryRoot" ]; then
              continue
            fi
            while IFS= read -r -d "" entry; do
              relativeEntry="''${entry#"$out/"}"
              if [[ "$relativeEntry" == *$'\n'* ]]; then
                echo "ida-nix: inventoried paths cannot contain newlines" >&2
                exit 1
              fi
              if [ -L "$entry" ]; then
                resolvedLink="$(readlink -f "$entry")" || {
                  echo "ida-nix: artifact symlink must resolve to an immutable regular file: $relativeEntry" >&2
                  exit 1
                }
                case "$resolvedLink" in
                  "${builtins.storeDir}/"*) ;;
                  *)
                    echo "ida-nix: artifact symlink must resolve to an immutable regular file: $relativeEntry" >&2
                    exit 1
                    ;;
                esac
                if [ ! -f "$resolvedLink" ]; then
                  echo "ida-nix: artifact symlink must resolve to an immutable regular file: $relativeEntry" >&2
                  exit 1
                fi
              fi
            done < <(find "$inventoryRoot" \( -type f -o -type l \) -print0)
          done

          {
            if [ -d "$out/share/ida" ]; then
              find "$out/share/ida" \( -type f -o -type l \) -printf '%P\n'
            fi
          } | LC_ALL=C sort > actual-artifacts

          if ! diff -u "${expectedArtifacts}" actual-artifacts; then
            echo "ida-nix: installed IDA artifacts differ from the declared inventory" >&2
            exit 1
          fi

          {
            if [ -d "$out/bin" ]; then
              find "$out/bin" \( -type f -o -type l \) -printf 'bin/%P\n'
            fi
          } | LC_ALL=C sort > actual-commands

          if ! diff -u "${expectedCommands}" actual-commands; then
            echo "ida-nix: installed plugin commands differ from the declared inventory" >&2
            exit 1
          fi

          ${commandChecks}
        '';
        meta = args.meta or { };
        passthru = (args.passthru or { }) // {
          idaPlugin = {
            inherit
              artifactRoots
              conflicts
              entrypointCollisionKeys
              entrypoints
              id
              idaVersions
              pythonAbi
              pythonPackages
              requires
              requiresDecompiler
              runtimePackages
              ;
            artifacts = normalizedArtifacts;
            commands = normalizedCommands;
            inherit contractMarker contractVersion;
            root = "${drv}/share/ida";
            inherit version;
          };
        };
      };
    in
    assert lib.assertMsg (validPluginId id)
      "ida-nix: plugin id must use lowercase ASCII letters, numbers, '.', '_', or '-'";
    assert lib.assertMsg (builtins.isString version) "ida-nix: plugin version must be a string";
    assert lib.assertMsg (
      artifactsValid && lib.unique artifactPaths == artifactPaths
    ) "ida-nix: plugin artifacts must be a unique, safe, exact IDAUSR inventory";
    assert lib.assertMsg (
      lib.unique entrypointCollisionKeys == entrypointCollisionKeys
    ) "ida-nix: plugin contains IDA entrypoints that collide case-insensitively without extensions";
    assert lib.assertMsg (
      commandsValid
      && lib.unique commandNames == commandNames
      && lib.unique selfCommandPaths == selfCommandPaths
      && lib.intersectLists reservedCommands commandNames == [ ]
    ) "ida-nix: plugin commands must have unique names and exact immutable executable owners";
    assert lib.assertMsg validVersionRange "ida-nix: plugin IDA version bounds are invalid";
    assert lib.assertMsg (
      pythonAbi == null
      || (builtins.isString pythonAbi && builtins.match "[0-9]+\\.[0-9]+" pythonAbi != null)
    ) "ida-nix: plugin Python ABI must use major.minor form, such as '3.14'";
    assert lib.assertMsg (
      builtins.isList conflicts
      && lib.all validPluginId conflicts
      && lib.unique conflicts == conflicts
      && !builtins.elem id conflicts
    ) "ida-nix: plugin conflicts must be unique plugin IDs and cannot include itself";
    assert lib.assertMsg
      (
        builtins.isList requires
        && lib.all validPluginId requires
        && lib.unique requires == requires
        && !builtins.elem id requires
        && lib.intersectLists requires conflicts == [ ]
      )
      "ida-nix: plugin requirements must be unique, non-conflicting plugin IDs and cannot include itself";
    assert lib.assertMsg (
      builtins.isList pythonPackages && lib.all lib.isDerivation pythonPackages
    ) "ida-nix: pythonPackages must contain derivations";
    assert lib.assertMsg (
      builtins.isList runtimePackages && lib.all lib.isDerivation runtimePackages
    ) "ida-nix: runtimePackages must contain derivations";
    assert lib.assertMsg (builtins.isBool requiresDecompiler)
      "ida-nix: requiresDecompiler must be a boolean";
    drv;

  versionCompatible =
    idaVersion: info:
    let
      minimum = info.idaVersions.min or null;
      maximum = info.idaVersions.maxExclusive or null;
    in
    (minimum == null || lib.versionAtLeast idaVersion minimum)
    && (maximum == null || lib.versionOlder idaVersion maximum);

  duplicates =
    values:
    lib.unique (lib.filter (value: lib.count (candidate: candidate == value) values > 1) values);

  compose =
    {
      ida,
      plugins ? [ ],
    }:
    let
      metadata = map pluginMetadata plugins;
      pluginEntries = lib.zipListsWith (plugin: info: { inherit info plugin; }) plugins metadata;
      pluginIds = map (info: info.id) metadata;
      installedArtifacts = lib.concatMap (info: map artifactPath info.artifacts) metadata;
      entrypointCollisionKeys = lib.concatMap (info: info.entrypointCollisionKeys) metadata;
      commandEntries = lib.concatMap (
        entry:
        map (
          command:
          command
          // {
            pluginId = entry.info.id;
            provider = if command.package == null then entry.plugin else command.package;
          }
        ) entry.info.commands
      ) pluginEntries;
      commandNames = map (command: command.name) commandEntries;
      duplicateIds = duplicates pluginIds;
      duplicateArtifacts = duplicates installedArtifacts;
      duplicateEntrypoints = duplicates entrypointCollisionKeys;
      duplicateCommands = duplicates commandNames;
      declaredConflicts = lib.concatMap (
        info: lib.filter (conflict: builtins.elem conflict pluginIds) info.conflicts
      ) metadata;
      missingRequirements = lib.concatMap (
        info:
        map (requirement: "${info.id} -> ${requirement}") (
          lib.filter (requirement: !builtins.elem requirement pluginIds) info.requires
        )
      ) metadata;
      incompatible = map (info: info.id) (
        lib.filter (info: !versionCompatible ida.version info) metadata
      );
      abiMismatch = map (info: info.id) (
        lib.filter (info: info.pythonAbi != null && info.pythonAbi != ida.ida.pythonAbi) metadata
      );
      pythonPackages = lib.unique (lib.concatMap (info: info.pythonPackages) metadata);
      pythonEnv = ida.ida.python.withPackages (_: pythonPackages);
      runtimePackages = lib.unique (lib.concatMap (info: info.runtimePackages) metadata);
      runtimeBinPath = lib.makeBinPath ([ pythonEnv ] ++ runtimePackages);
      pluginRuntimeLibraryPath = lib.makeLibraryPath runtimePackages;
      combinedRuntimeLibraryPath = lib.concatStringsSep ":" (
        [
          ida.ida.root
          ida.ida.runtimeLibraryPath
        ]
        ++ lib.optional (runtimePackages != [ ]) pluginRuntimeLibraryPath
      );
      pluginRoots = map (info: info.root) metadata;
      idausrSuffix = lib.concatStringsSep ":" pluginRoots;
      sharedWrapperFlags = lib.escapeShellArgs [
        "--run"
        ''export IDAUSR="''${IDAUSR:-$HOME/.idapro}${
          lib.optionalString (idausrSuffix != "") ":${idausrSuffix}"
        }"''
        "--prefix"
        "LD_LIBRARY_PATH"
        ":"
        combinedRuntimeLibraryPath
        "--prefix"
        "PATH"
        ":"
        runtimeBinPath
        "--prefix"
        "PYTHONPATH"
        ":"
        "${pythonEnv}/${ida.ida.python.sitePackages}"
      ];
      commandWrappers = lib.concatMapStringsSep "\n" (command: /* sh */ ''
        if [ -e "$out/bin/${command.name}" ]; then
          echo "ida-nix: plugin command collides with the IDA package: ${command.name}" >&2
          exit 1
        fi
        if [ ! -x "${command.provider}/${command.path}" ]; then
          echo "ida-nix: declared plugin command is missing: ${command.pluginId} -> ${command.name}" >&2
          exit 1
        fi
        makeWrapper "${command.provider}/${command.path}" "$out/bin/${command.name}" \
          --set IDADIR "${ida.ida.root}" \
          ${sharedWrapperFlags} \
          --prefix QT_PLUGIN_PATH : "${ida.ida.qtPluginPath}"
      '') commandEntries;
      profileName = "ida-pro-${ida.version}${
        lib.optionalString (pluginIds != [ ]) "-with-${lib.concatStringsSep "-" pluginIds}"
      }";
      joined =
        pkgs.runCommand profileName
          {
            inherit (ida) version;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            inherit (ida) meta;
            passthru = {
              inherit
                pluginIds
                pluginRoots
                plugins
                pythonEnv
                runtimePackages
                ;
              commands = commandNames;
              requiresDecompiler = lib.any (info: info.requiresDecompiler) metadata;
              inherit (ida) ida;
              unwrapped = ida;
              withPlugins =
                additional:
                compose {
                  inherit ida;
                  plugins = plugins ++ additional;
                };
            };
          }
          ''
            mkdir -p "$out/bin"

            for directory in lib opt share; do
              if [ -e "${ida}/$directory" ]; then
                ln -s "${ida}/$directory" "$out/$directory"
              fi
            done

            for program in ida idat; do
              if [ -x "${ida}/bin/$program" ]; then
                makeWrapper "${ida}/bin/$program" "$out/bin/$program" \
                  ${sharedWrapperFlags}
              fi
            done

            ${commandWrappers}
          '';
    in
    assert lib.assertMsg (
      lib.isDerivation ida
      && ida ? version
      && builtins.isString ida.version
      && ida ? ida
      && ida.ida ? python
      && ida.ida ? pythonAbi
      && ida.ida ? qtPluginPath
      && ida.ida ? root
      && ida.ida ? runtimeLibraryPath
    ) "ida-nix: composition requires an IDA base package";
    assert lib.assertMsg (
      duplicateIds == [ ]
    ) "ida-nix: duplicate plugin ids: ${lib.concatStringsSep ", " duplicateIds}";
    assert lib.assertMsg (
      duplicateArtifacts == [ ]
    ) "ida-nix: colliding installed artifacts: ${lib.concatStringsSep ", " duplicateArtifacts}";
    assert lib.assertMsg (
      duplicateEntrypoints == [ ]
    ) "ida-nix: colliding IDA entrypoints: ${lib.concatStringsSep ", " duplicateEntrypoints}";
    assert lib.assertMsg (
      duplicateCommands == [ ]
    ) "ida-nix: colliding plugin commands: ${lib.concatStringsSep ", " duplicateCommands}";
    assert lib.assertMsg (
      declaredConflicts == [ ]
    ) "ida-nix: conflicting plugins enabled: ${lib.concatStringsSep ", " declaredConflicts}";
    assert lib.assertMsg (
      missingRequirements == [ ]
    ) "ida-nix: missing plugin requirements: ${lib.concatStringsSep ", " missingRequirements}";
    assert lib.assertMsg (incompatible == [ ])
      "ida-nix: plugins incompatible with IDA ${ida.version}: ${lib.concatStringsSep ", " incompatible}";
    assert lib.assertMsg (
      abiMismatch == [ ]
    ) "ida-nix: plugins built for the wrong Python ABI: ${lib.concatStringsSep ", " abiMismatch}";
    joined;
in
{
  inherit
    compose
    isIdaPlugin
    mkIdaPlugin
    pluginMetadata
    ;
}
