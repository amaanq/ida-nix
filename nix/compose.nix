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
        ln -s ${ida}/{lib,opt,share} "$out/"

        for program in ida idat; do
          if [ -x "${ida}/bin/$program" ]; then
            makeWrapper "${ida}/bin/$program" "$out/bin/$program" ${pluginEnv}
          fi
        done

        ${lib.concatMapStrings wrapCommand (collect "commands")}
      '';
in
compose
