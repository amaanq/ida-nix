# ida-nix

Composable Nix packaging for IDA Pro. You supply the installer, the flake
packages it once, and typed, versioned plugins compose around it. IDA lives in
a single derivation, so changing a plugin only rebuilds a thin profile and
launcher layer.

Currently targets IDA 9.2 on `x86_64-linux`.

## Outputs

| Output                 | Contents                                                      |
| ---------------------- | ------------------------------------------------------------- |
| `ida-pro`              | IDA 9.2 without third-party plugins                           |
| `ida-pro-full`         | IDA, BinDiff/BinExport, and ida-pro-mcp                       |
| `ida-pro-malware`      | The full profile plus capa Explorer                           |
| `plugin-bindiff`       | BinDiff/BinExport built with SDK 9.2, compatible through 9.4  |
| `plugin-ida-pro-mcp`   | The IDA-side MCP bridge                                       |
| `plugin-capa-explorer` | capa Explorer, available as an opt-in heavy profile           |
| `ida-pro-mcp`          | The GUI-bridge server plus the IDALib-capable command payload |

BinDiff is built from my IDA 9-compatible
[`bindiff`](https://github.com/amaanq/bindiff) fork. The open-source native
engine and IDA plugins are included, but not the Java UI, since it needs the
commercial yFiles 2.x library.

## Install

Nix can't download IDA, so add the installer to the store yourself. It has to
match the hash in [`nix/ida/releases.nix`](nix/ida/releases.nix).

```console
nix store add --mode flat --name ida-pro_92_x64linux.run ./ida-pro_92_x64linux.run
nix build .#ida-pro-full
```

## Use from another Tack project

```console
tack add ida-nix github:amaanq/ida-nix --follows=nixpkgs=nixpkgs
```

Then apply the overlay and pick plugins explicitly.
[`examples/consumer-flake.nix`](examples/consumer-flake.nix) is a full
template.

```nix
pkgs = import nixpkgs {
  inherit system;
  config.allowUnfree = true;
  overlays = [ ida-nix.overlays.default ];
};

ida = pkgs.ida-pro.withPlugins [
  pkgs.idaPlugins.bindiff
  pkgs.idaPlugins.ida-pro-mcp
];
```

The NixOS module does the same composition. Import
`ida-nix.nixosModules.default` and set `programs.ida-pro.enable`, `package`,
and `plugins`.

For an IDA release that isn't in `releases.nix`, `pkgs.mkIda` takes an
explicit installer path, Python interpreter, and release metadata. The Python
ABI and native SDK checks are hard on purpose. Updating IDA means verifying
the interpreter and rebuilding native plugins against that release's SDK, not
just changing a version string.

## Plugin API

Every plugin is built with `mkIdaPlugin`, which produces a validated
`idaPlugin` contract. Artifacts go under `$out/share/ida` using IDA's normal
user-directory layout (`plugins`, `loaders`, `procs`, `cfg`, `idc`, `ids`,
`sig`, `til`, `themes`).

```nix
myPlugin = pkgs.mkIdaPlugin {
  id = "my-plugin";
  version = "1.0.0";
  src = ./my-plugin;
  artifacts = [
    {
      root = "plugins";
      path = "my_plugin.py";
      # entrypoint = false for manifests and data files
    }
  ];
  # names of bin/<name> executables the plugin ships,
  # or { name, package, path } to wrap another package's binary
  commands = [ ];
  idaVersions = {
    min = "9.0";
    maxExclusive = "10.0";
  };
  pythonAbi = null;

  installPhase = ''
    install -Dm644 "$src/my_plugin.py" \
      "$out/share/ida/plugins/my_plugin.py"
  '';
};
```

Validation lives in a separate outer derivation that diffs the declared
artifact and command inventories against what actually got installed, so a
payload build hook can't skip it. Artifact symlinks must resolve to regular
files in the store. Composition rejects duplicate IDs, entrypoint collisions
(per root, case-insensitive, extension-stripped, matching IDA's discovery
rules), command collisions, declared conflicts, missing requirements,
incompatible IDA versions, and mismatched Python ABIs. Plugin roots are
appended to `IDAUSR`, and the user's writable `${IDAUSR:-$HOME/.idapro}` stays
first, so local configuration and deliberate overrides keep working.

## MCP notes

ida-pro-mcp is pinned at 2.0.0. The package doesn't run the upstream
self-installer or touch MCP client configuration under `$HOME`, and the
generated server code is produced during the Nix build instead of at runtime.

`nix run .#ida-pro-mcp` starts the GUI-bridge server. `idalib-mcp` needs a
licensed IDA installation, so use the command from `ida-pro-full`, where it's
wrapped with the matching `IDADIR`, `idapro`, and runtime libraries. The
plugin declares a decompiler requirement because the IDALib server initializes
Hex-Rays unconditionally. The GUI bridge listens on loopback and can mutate
the open database. Only enable unsafe/debugger operations when you trust both
the client and the binary you're analyzing.

## Verification

```console
nix flake check -L
```

The suite needs no proprietary software. It builds a synthetic installer,
exercises the real launcher and ordered `IDAUSR` composition, runs the
contract rejection tests (including phase, builder, symlink, and
command-ownership escapes), and builds the pinned open-source BinDiff, MCP,
and capa packages.

There's deliberately no real IDA smoke test in public CI, since the licensed
installer isn't available there. Run the composed package against `idat -A`
before promoting a new IDA, SDK, Qt, or Python combination. The 9.2 pin
selects Python 3.14, which Hex-Rays doesn't explicitly guarantee, so a pin
update isn't validated until real GUI and headless smoke tests pass.

## Pins

Tack is the only input resolver, and there's no `flake.lock`. Intent lives in
`.tack/pins.toml`, and `.tack/pins.lock.json` records the immutable revisions
and hashes. `tack look` reports newer upstream revs, `tack update` relocks.
BinDiff is pinned to the clean IDA 9.2 fork revision, before the later
experimental debug logging and host-specific paths.

## Scope and provenance

This is an independent clean-room implementation built from public facts like
installer arguments, IDA's environment-variable behavior, and ELF dependency
requirements. No source code or artwork was copied from the reference overlay.
Third-party packages keep their own licenses and notices. See
[`THIRD_PARTY.md`](THIRD_PARTY.md).

IDA Pro is proprietary software. Complying with the Hex-Rays license and the
licenses of enabled plugins is on you.
