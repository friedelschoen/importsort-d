# Sort Imports for [*D*](https://dlang.org/)

> `sortimport-d` can sort your dozens of `import`'s in a `.d` file (no matter where)

## Installation

### Prerequirements

- [`dmd`](https://dlang.org/)

### Building

Get the repository with `git`:
```
$ git clone https://github.com/friedelschoen/importsort-d
$ cd importsort-d
```

And finally build this project with
```
$ make
# make install
```

## Usage

```
$ importsort-d [--inline [--keep]] [--out <output>] [<input>]
```

> `input` may be omitted or set to `-` to read from STDIN

| option                  | description                                    |
|:-----------------------:| ---------------------------------------------- |
| `-i`, `--inline`        | changes the input                              |
| `-k`, `--keep`          | keeps a backup of the input                    |
| `-o`, `--output <path>` | writes to `path` rather then writing to STDOUT |


## License

This whole project is licensed under the beautiful terms of the `zlib-license`.

Further information [here](LICENSE)