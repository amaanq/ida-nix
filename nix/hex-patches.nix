{ lib }:
{
  mkHexPatcher =
    {
      pkgs,
      hexPatches,
      name ? "ida-hex-patcher",
    }:
    let
      isHex = value: builtins.match "([0-9a-fA-F]{2})+" value != null;
      validPatch =
        patch:
        isHex patch.from
        && isHex patch.to
        && builtins.stringLength patch.from == builtins.stringLength patch.to;
      patchCommand =
        patch:
        let
          countCheck =
            if patch ? assertCount then
              ''die "Expected ${toString patch.assertCount} substitutions, did $count in $ARGV\n" if $count != ${toString patch.assertCount}''
            else
              ''die "No substitutions in $ARGV\n" if $count == 0'';
        in
        ''
          perl -0777 -pi -e 'my $count = (s/\Q''${\pack("H*","${patch.from}")}\E/''${\pack("H*","${patch.to}")}/g) || 0; ${countCheck}' "$idaRoot"/${lib.escapeShellArg patch.filename}
        '';
    in
    assert lib.assertMsg (lib.all validPatch hexPatches)
      "ida-nix: hex patches need equal-length, nonempty, even-length hex strings";
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.perl ];
      text = ''
        if [ "$#" -ne 1 ]; then
          echo "usage: $0 IDA_ROOT" >&2
          exit 2
        fi

        idaRoot=$1
        ${lib.concatMapStrings patchCommand hexPatches}
      '';
    };
}
