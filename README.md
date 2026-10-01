# ida-nix

Composable Nix packaging for IDA Pro. You supply the installer, the flake
packages it once, and plugins compose around it. IDA lives in
a single derivation, so changing a plugin only rebuilds a thin profile and
launcher layer.

Currently targets IDA 9.5 on `x86_64-linux`, with 9.2 still available through
`mkIda`.

## Outputs

| Output                 | Contents                                                      |
| ---------------------- | ------------------------------------------------------------- |
| `ida-pro`              | IDA 9.5 without third-party plugins                           |
| `ida-pro-full`         | IDA, BinDiff/BinExport, and the official Hex-Rays MCP server  |
| `ida-pro-malware`      | The full profile plus capa Explorer                           |
| `plugin-bindiff`       | BinDiff/BinExport built with SDK 9.2, compatible through 9.5  |
| `plugin-ida-mcp`       | The GUI bridge for the official Hex-Rays MCP server           |
| `plugin-capa-explorer` | capa Explorer, available as an opt-in heavy profile           |
| `ida-mcp`              | The official Hex-Rays MCP server                              |

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
  pkgs.idaPlugins.ida-mcp
];
```

The NixOS module does the same composition. Import
`ida-nix.nixosModules.default` and set `programs.ida-pro.enable`, `package`,
and `plugins`.

For an IDA release that isn't in `releases.nix`, pass `pkgs.mkIda` your own
`release` attribute set, plus `installer` and `python` if it has no hash or
Python pin. Updating IDA means verifying the interpreter and rebuilding native
plugins against that release's SDK, not just changing a version string.

## Base customizations

`pkgs.mkIda` takes `files` and `hexPatches` for changes that must be applied
to the installed IDA tree. `files` maps individual source files to paths
relative to the IDA root. `hexPatches` replaces exact byte strings after those
files are installed and before fixup runs.

```nix
pkgs.mkIda {
  files = [
    {
      source = ./idapro.hexlic;
      target = "idapro.hexlic";
    }
  ];
  hexPatches = [
    {
      filename = "libida.so";
      from = "00112233";
      to = "44556677";
      assertCount = 1;
    }
  ];
}
```

Patch values must be nonempty, equal-length hex strings. Patches replace every
occurrence and fail when nothing matches. Set `assertCount` when a release has a
known exact match count.

For installers managed outside `mkIda`, `ida-nix.lib.mkHexPatcher` builds the
same patcher. The generated command takes the IDA root as its only
argument.

```nix
patcher = ida-nix.lib.mkHexPatcher {
  inherit pkgs hexPatches;
};
```

## Plugin API

A plugin is any derivation that installs into `$out/share/ida` using IDA's
user-directory layout (`plugins`, `loaders`, `procs`, `til`, and so on).
Anything else the profile needs goes in `passthru.idaPlugin`.

```nix
myPlugin = pkgs.stdenvNoCC.mkDerivation {
  pname = "ida-plugin-my-plugin";
  version = "1.0.0";
  src = ./my-plugin;

  installPhase = ''
    install -Dm644 my_plugin.py "$out/share/ida/plugins/my_plugin.py"
  '';

  passthru.idaPlugin = {
    # added to the profile's Python environment
    pythonPackages = [ ];
    # added to PATH and LD_LIBRARY_PATH
    runtimePackages = [ ];
    # executables wrapped into the profile's bin with IDADIR set
    commands = [ ];
  };
};
```

Plugin roots are appended to `IDAUSR`, and the user's writable
`${IDAUSR:-$HOME/.idapro}` stays first, so local configuration and deliberate
overrides keep working.

## MCP notes

`ida-pro-full` ships the official [Hex-Rays MCP
server](https://github.com/HexRaysSA/ida-mcp), which needs IDA 9.4. Run
`ida-mcp stdio` from the composed package so idalib workers get the matching
`IDADIR`. It shares one database between the GUI and any number of agents,
and records every session, code and results included, under
`$IDAUSR/mcp/sessions`. Its `execute_python` tool runs arbitrary Python inside
IDA, so treat the binary under analysis as untrusted input.

## Verification

```console
nix flake check -L
```

The suite needs no proprietary software. It builds a synthetic installer,
exercises the real launcher, ordered `IDAUSR` composition, and base
customizations, and builds the pinned open-source BinDiff, MCP, and capa
packages.

There's deliberately no real IDA smoke test in public CI, since the licensed
installer isn't available there. Run the composed package against `idat -A`
before promoting a new IDA, SDK, Qt, or Python combination. The 9.5 pin
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
