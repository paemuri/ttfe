# TTFE

[![License][badge-1-img]][badge-1-link]

2048 game in the terminal!

## Game

[![Example](https://asciinema.org/a/349256.svg "Example")][1]

## Installation

AUR / Arch Linux:

```sh
$AUR_HELPER -S ttfe
```

Nix:

```sh
nix profile install sourcehut:~paemuri/nix-pkgs#ttfe
```

## Usage

```sh
ttfe
```

Or, to run the game with a different grid size (e.g. 6):

```sh
ttfe 6
```

The bigger the grid, the easier the game gets (up to 16).

Move the tiles with the arrow keys or with vi-style navigation. Quit with `q` or
Ctrl-C.

## Source code

The main repository is on [SourceHut][source-srht]. A mirror exists on
[GitHub][source-github] for convenience, but it might occasionally be
outdated.

### License and contribution

This project's code is in the public domain. See the
[LICENSE file][source-license].

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you shall be in the public domain, without any
additional terms or conditions.

[1]: https://asciinema.org/a/349256

[badge-1-img]: https://img.shields.io/badge/license-Unlicense-green?style=flat-square
[badge-1-link]: ./LICENSE

[source-srht]: https://git.sr.ht/~paemuri/ttfe
[source-github]: https://github.com/paemuri/ttfe
[source-license]: ./LICENSE
