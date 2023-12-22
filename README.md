# Sort Imports for [D](https://dlang.org/)

`sortimport-d` can sort your dozens of `import`'s in a `.d` file (no matter where)

## Installation

### Prerequisite

- [`dub`](https://dub.pm/)

### Building from HEAD

Get the repository with `git` and compile everything with `dub`
```bash
$ git clone https://github.com/friedelschoen/importsort-d
$ cd importsort-d
$ dub build
```

If everything went fine, there should be a binary at `bin/importsort-d`.

Copy this into a directory included in `$PATH` (`/usr/bin` for example) to make this command work globally.

```bash
$ sudo cp bin/importsort-d /usr/bin/
```

or add this into your `.bashrc`, `.zshrc`, etc.
```bash
export PATH=$PATH:"<path/to/importsort-d>/bin/" # on bash or zsh
fish_add_path "<path/to/importsort-d>/bin/"     # on fish-shell
```

### Building with DUB

```bash
$ dub fetch importsort-d
$ dub run importsort-d -- --help
```

This won't install the command globally, you always have to run `dub run importsort-d <args>`

## Usage

see
```bash
$ importsort-d --help
$ dub run importsort-d -- --help
```

## Documentation

Look at the documentation at [`dpldocs.info`](https://importsort-d.dpldocs.info/), if you want to use this project in code.

## FAQ

### How to add `importsort-d` to Visual Studio Code?
> There's a plugin called [Run on Save](https://marketplace.visualstudio.com/items?itemName=emeraldwalk.RunOnSave). You can install it and set `importsort-d` as an onSave-hook: 
```json
...
"emeraldwalk.runonsave": {
    "commands": [
        {
            "cmd": "importsort-d --inplace ${file}",
            "match": "\\.d$"
        }
    ]
},
...
```

### How to add `importsort-d` to VIM/NeoVIM?
> Just add this to your `.vimrc` or `init.vim`
```vim
:autocmd BufWritePost * silent !importsort-d --inplace <afile>
```

### Are cats cool?
> Yes

## ToDo's

- [x] recursive searching (`v0.2.0`)
- [x] merge imports (`v0.3.0`)
- [ ] watch-mode (struggling with save-timings - can clear files)
  - you can add importsort-d into your onSave-hooks
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
- added documentation for contributers (or people who really want to see my code)

## License

This whole project is licensed under the beautiful terms of the `zlib-license`.

Further information [here](LICENSE).

> made with love and a lot of cat memes
