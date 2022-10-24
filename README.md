# Sort Imports for [D](https://dlang.org/)

`sortimport-d` can sort your dozens of `import`'s in a `.d` file (no matter where)

## Installation

### Prerequisite

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
$ importsort-d [-h] [-v] [-r] [-m] [-i] [-o <out>] [-k] [-a] [-r] <input...>
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
| `-m, --merge`         | merge imports which uses same file             |
|                       |                                                |
| `-r, --recursive`     | recursively search in directories              |
| `-i, --inline`        | changes the input                              |
| `-o, --output <path>` | writes to `path` rather then writing to STDOUT |

## Documentation

Look at the documentation on [`dpldocs.info`](https://importsort-d.dpldocs.info/), if you want to use this project in code.

## FAQ

For example, how to add `importsort-d` to Visual Studio Code and other: [go here](/docs/tips-tricks)

## ToDo's

- [x] recursive searching (`v0.2.0`)
- [x] merge imports (`v0.3.0`)
- [ ] watch-mode (struggling with save-timings - can clear files)
  - you can add importsort-d into your onSave-hooks (e. g. [Run on Save](https://marketplace.visualstudio.com/items?itemName=emeraldwalk.RunOnSave) on VSCode)
- [ ] support multiple imports in one line (demilited by `;`)
- [ ] stripping unused imports (maybe)

> you got some ideas? Issue them!

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

### `v0.3.0`
- added `--merge` (see above)

### `v0.3.1`
- added documentation for contributers (or people who wan't to see my code)

## License

This whole project is licensed under the beautiful terms of the `zlib-license`.

Further information [here](LICENSE).

> made with love and a lot of cat memes