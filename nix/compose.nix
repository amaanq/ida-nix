{ pkgs }:
let
  inherit (pkgs) lib;
  compose =
    ida: plugins:
    let
      collect = name: lib.unique (lib.concatMap (plugin: plugin.idaPlugin.${name} or [ ]) plugins);
      runtimePackages = collect "runtimePackages";
      pythonEnv = ida.ida.python.withPackages (_: collect "pythonPackages");
      idausr = lib.concatMapStrings (plugin: ":${plugin}/share/ida") plugins;
      pluginEnv = lib.escapeShellArgs (
        [
          "--run"
          ''export IDAUSR="''${IDAUSR:-$HOME/.idapro}${idausr}"''
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath ([ pythonEnv ] ++ runtimePackages))
          "--prefix"
          "PYTHONPATH"
          ":"
          "${pythonEnv}/${ida.ida.python.sitePackages}"
        ]
        ++ lib.optionals (runtimePackages != [ ]) [
          "--prefix"
          "LD_LIBRARY_PATH"
          ":"
          (lib.makeLibraryPath runtimePackages)
        ]
      );
      infoPlist = pkgs.writeText "Info.plist" (
        lib.generators.toPlist { escape = true; } {
          CFBundleExecutable = "IDA Pro";
          CFBundleIdentifier = "com.hexrays.ida";
          CFBundleName = "IDA Pro";
          CFBundleDisplayName = "IDA Pro";
          CFBundlePackageType = "APPL";
          CFBundleIconFile = "appico.icns";
          CFBundleVersion = ida.version;
          CFBundleShortVersionString = ida.version;
          NSHighResolutionCapable = true;
          CFBundleDocumentTypes = [
            {
              CFBundleTypeName = "IDA Pro Database";
              CFBundleTypeExtensions = [
                "idb"
                "i64"
              ];
              CFBundleTypeRole = "Editor";
            }
          ];
        }
      );
      wrapCommand = command: ''
        makeWrapper ${command} "$out/bin/$(basename ${command})" \
          ${pluginEnv} \
          --set IDADIR ${ida.ida.root} \
          --prefix LD_LIBRARY_PATH : ${ida.ida.runtimeLibraryPath} \
          --prefix QT_PLUGIN_PATH : ${ida.ida.qtPluginPath}
      '';
    in
    pkgs.runCommand "ida-pro-${ida.version}"
      {
        inherit (ida) version meta;
        nativeBuildInputs = [ pkgs.makeWrapper ];
        passthru = {
          inherit (ida) ida;
          inherit plugins pythonEnv;
          unwrapped = ida;
          withPlugins = additional: compose ida (plugins ++ additional);
        };
      }
      ''
        mkdir -p "$out/bin"
        for entry in ${ida}/*; do
          [ "$entry" = ${ida}/bin ] || ln -s "$entry" "$out/"
        done

        for program in ida idat; do
          if [ -x "${ida}/bin/$program" ]; then
            makeWrapper "${ida}/bin/$program" "$out/bin/$program" ${pluginEnv}
          fi
        done

        ${lib.concatMapStrings wrapCommand (collect "commands")}
        ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
          bundle="$out/Applications/IDA Pro.app/Contents"
          install -Dm644 ${infoPlist} "$bundle/Info.plist"
          install -Dm644 ${ida.ida.app}/Contents/Resources/appico.icns "$bundle/Resources/appico.icns"
          makeWrapper "$out/bin/ida" "$bundle/MacOS/IDA Pro"
        ''}
      '';
in
compose
