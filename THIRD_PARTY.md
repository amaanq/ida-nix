# Third-party software

`ida-nix` pins, builds, or adapts these projects. Their source trees are
fetched rather than vendored, except for Tack's generated resolver.

| Project                                                         | Use                                            | License     |
| --------------------------------------------------------------- | ---------------------------------------------- | ----------- |
| [IDA Pro](https://hex-rays.com/ida-pro/)                        | User-supplied application                      | Proprietary |
| [amaanq/bindiff](https://github.com/amaanq/bindiff)             | BinDiff engine and IDA plugins                 | Apache-2.0  |
| [google/binexport](https://github.com/google/binexport)         | BinExport IDA plugin                           | Apache-2.0  |
| [HexRaysSA/ida-sdk](https://github.com/HexRaysSA/ida-sdk)       | Native plugin build SDK                        | MIT         |
| [mrexodia/ida-pro-mcp](https://github.com/mrexodia/ida-pro-mcp) | MCP servers and IDA bridge                     | MIT         |
| [Hex-Rays/idapro](https://pypi.org/project/idapro/)             | IDALib Python bootstrap                        | MIT         |
| [mandiant/capa](https://github.com/mandiant/capa)               | Optional capability explorer                   | Apache-2.0  |
| [Tack](https://github.com/manic-systems/tack)                   | Vendored input resolver at `.tack/default.nix` | EUPL-1.2    |

The source distributions carry the authoritative copyright and license
notices. This file is an inventory, not a replacement for them. The EUPL-1.2
text for the vendored Tack resolver is under `LICENSES/`, and the repository's
own code is covered by `LICENSE`. Fetched packages also declare their licenses
through Nix metadata.
