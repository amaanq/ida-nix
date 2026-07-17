# Contributing

Keep the installer-derived IDA package, plugin payloads, and the composition
layer separate. New plugin packages must be built through `mkIdaPlugin` and
must declare everything IDA can see, meaning entrypoints, exact native SDK
compatibility, Python ABI requirements, command owners, conflicts, and
licenses. Don't override the returned validator derivation, since that
invalidates its contract identity and composition will reject it.

Run the full local suite before submitting a change.

```console
nix fmt
nix flake check -L
nix develop -c actionlint
nix develop -c statix check .
nix develop -c deadnix --fail .
tack look
```

Never commit IDA installers, activation or license files, databases,
proprietary SDKs, crash dumps, or anything copied out of an IDA installation.
Open-source license and notice files needed for redistribution are fine and
expected. Tests that need licensed IDA must be opt-in and must not upload the
installer or activation state.

Source intent pins should name an immutable tag or commit when practical.
Rolling inputs like `nixpkgs` can track a maintained branch instead. The
generated Tack lock must always resolve every input to an immutable revision
and content hash. If a fork or unreleased revision is necessary, say why.
