# Consumer template

Copy `consumer-flake.nix` into your project root as `flake.nix`, then create
the Tack pins it imports.

```console
tack init
tack add nixpkgs github:NixOS/nixpkgs/nixos-unstable
tack add ida-nix github:amaanq/ida-nix --follows=nixpkgs=nixpkgs
```

The template deliberately doesn't use the special filename here, since
otherwise it'd look like a second flake inside this repository.
