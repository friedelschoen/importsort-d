# Sort Imports for [D](https://dlang.org/)

<img src="assets/importsort-d.png" alt="logo" width="256" /> 

`sortimport-d` can sort your dozens of `import`'s in a `.d` file (no matter where)

## Installation

## Prerequisite

- [`dub`](https://dub.pm/)

### Building from HEAD

Get the repository with `git` and compile everything with `dub`
```
$ git clone https://github.com/friedelschoen/importsort-d
$ cd importsort-d
$ dub build
```

If everything went fine, there should be a binary at `bin/importsort-d`.

Copy this into a directory included in `$PATH` (`/usr/bin` for example) to make this command work globally.

### Building with DUB

```
$ dub fetch importsort-d
$ dub run importsort-d -- --help
```

This won't install the command globally, you always have to run `dub run importsort-d <args>`

## Usage

```
$ importsort-d [-h] [-v] [-r] [-i] [-o <out>] [-k] [-a] [-r] <input...>
```
`input` may be omitted or set to `-` to read from STDIN

| option                | description                                    |
| --------------------- | ---------------------------------------------- |
| `-h, --help`          | prints a help message                          |
| `-v, --verbose`       | prints useful debug messages                   |
|                       |                                                |
| `-k, --keep`          | keeps the line as-is instead of formatting     |
| `-a, --attribute`     | public and static imports first                |
| `-b, --binding`       | sorts by binding rather then the original      |
|                       |                                                |
| `-r, --recursive`     | recursively search in directories              |
| `-i, --inline`        | changes the input                              |
| `-o, --output <path>` | writes to `path` rather then writing to STDOUT |

## TODO's

- [x] recursive searching (`v0.2.0`)
- [ ] watch-mode (struggling with save-timings - can clear files)
  - you can add importsort-d into your onSave-hooks (e. g. [Run on Save](https://marketplace.visualstudio.com/items?itemName=emeraldwalk.RunOnSave) on VSCode)
- [ ] support multiple imports in one line (demilited by `;`)
- [x] merge imports (`v0.3.0`)
- [ ] stripping unused imports (maybe)

## Changelog

### `v0.1.0`
- the very first version
- not a lot is implemented

### `v0.2.0`
- added `--recursive` (see above)
- option `--keep` becomes disabling formatting
- option `--inline` doen't copy the original but creates a `*.new` and renames it afterwards
- option `--original` becomes `--binding` and sorts by original by default
- refactoring code

## License

This whole project is licensed under the beautiful terms of the `zlib-license`.

Further information [here](LICENSE)

> made with love and a lot of cat memes