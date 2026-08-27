{ lib }:
let
  hasOnlyAttrs =
    allowed: value: lib.all (name: builtins.elem name allowed) (builtins.attrNames value);
  isRelativePath =
    value:
    builtins.isString value
    && value != ""
    && !lib.hasPrefix "/" value
    && !lib.hasInfix "\n" value
    && !lib.hasInfix "\r" value
    && lib.all (component: component != "" && component != "." && component != "..") (
      lib.splitString "/" value
    );
  isHex =
    value:
    builtins.isString value
    && value != ""
    && lib.mod (builtins.stringLength value) 2 == 0
    && builtins.match "[0-9a-fA-F]+" value != null;
  validHexPatch =
    patch:
    builtins.isAttrs patch
    && hasOnlyAttrs [
      "assertCount"
      "filename"
      "from"
      "to"
    ] patch
    && patch ? filename
    && isRelativePath patch.filename
    && patch ? from
    && isHex patch.from
    && patch ? to
    && isHex patch.to
    && builtins.stringLength patch.from == builtins.stringLength patch.to
    && (
      (patch.assertCount or null) == null || (builtins.isInt patch.assertCount && patch.assertCount > 0)
    );
  mkHexPatcher =
    {
      pkgs,
      hexPatches,
      name ? "ida-hex-patcher",
    }:
    let
      patchCommands = lib.concatMapStringsSep "\n" (
        patch:
        let
          assertCount = patch.assertCount or null;
          countCheck =
            if assertCount == null then
              ''die "No substitutions in $ARGV\n" if $count == 0''
            else
              ''die "Expected ${toString assertCount} substitutions, did $count in $ARGV\n" if $count != ${toString assertCount}'';
        in
        ''
          perl -0777 -pi -e 'my $count = (s/\Q''${\pack("H*","${patch.from}")}\E/''${\pack("H*","${patch.to}")}/g) || 0; ${countCheck}' "$idaRoot"/${lib.escapeShellArg patch.filename}
        ''
      ) hexPatches;
    in
    assert lib.assertMsg (builtins.isList hexPatches) "ida-nix hexPatches must be a list";
    assert lib.assertMsg (lib.all validHexPatch hexPatches)
      "ida-nix hexPatches contains an invalid patch";
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.perl ];
      text = ''
        if [ "$#" -ne 1 ]; then
          echo "usage: $0 IDA_ROOT" >&2
          exit 2
        fi

        idaRoot=$1
        ${patchCommands}
      '';
    };
in
{
  inherit
    isRelativePath
    mkHexPatcher
    validHexPatch
    ;
}
