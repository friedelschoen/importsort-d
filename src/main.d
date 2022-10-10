// (c) 2022 Friedel Schon <derfriedmundschoen@gmail.com>

module importsort;

import core.stdc.stdlib : exit;
import std.algorithm : map, sort, findSplit;
import std.array : array;
import std.file : copy, remove;
import std.regex : ctRegex, matchFirst;
import std.stdio : File, stderr, stdin, stdout;
import std.string : format, split, strip, stripLeft, indexOf;
import std.typecons : Yes, Tuple, tuple;

//alias Identifier = Tuple!(string, string, string); // name, alias, sortBy
struct Identifier {
	string original;
	string alias_;

	string sortBy() {
		if (sortOriginal)
			return original;
		else
			return hasAlias ? alias_ : original;
	}

	bool hasAlias() {
		return alias_ != null;
	}
}

struct Import {
	bool public_;
	bool static_;
	Identifier name;
	Identifier[] idents;
	string begin;
	string end;
}

const pattern = ctRegex!`^(\s*)(?:(public|static)\s+)?import\s+([a-zA-Z._]+)(?:\s*=\s*(\w+))?\s*(:\s*\w+(?:\s*=\s*\w+)?(?:\s*,\s*\w+(?:\s*=\s*\w+)?)*)?\s*;[ \t]*([\n\r]*)$`;

const help = (string arg0) => "Usage: " ~ arg0 ~ " [--inline [--keep]] [--out <output>] [input]
  <path> can be ommitted or set to '-' to read from stdin

Options:
  -k, --keep ....... keeps a backup if using '--inline'
  -i, --inline ..... writes to the input
  -o, --out <path> . writes to `path` instead of stdout

  -r, --original ... sort by original not by binding";

bool inline = false;
bool keep = false;
string output = null;
string path = null;
bool sortOriginal = false;

void main(string[] args) {
	bool nextout = false;

	foreach (arg; args[1 .. $]) {
		if (nextout) {
			output = arg;
			nextout = false;
		}
		if (arg == "--help" || arg == "-h") {
			stdout.writeln(help(args[0]));
			return;
		}
		if (arg == "--keep" || arg == "-k") {
			keep = true;
		} else if (arg == "--inline" || arg == "-i") {
			inline = true;
		} else if (arg == "--original" || arg == "-r") {
			sortOriginal = true;
		} else if (arg == "--out" || arg == "-o") {
			if (output != null) {
				stderr.writeln("error: output already specified");
				stderr.writeln(help(args[0]));
				exit(1);
			}
			nextout = true;
		} else {
			if (path != null) {
				stderr.writeln("error: input already specified");
				stderr.writeln(help(args[0]));
				exit(1);
			}
			path = arg;
		}
	}
	if (output != null && output == path) {
		stderr.writeln("error: input and output cannot be the same; use '--inline'");
		stderr.writeln(help(args[0]));
		exit(1);
	}
	if (!inline && keep) {
		stderr.writeln("error: you have to specify '--keep' in combination with '--inline'");
		exit(1);
	}
	if (inline && output != null) {
		stderr.writeln("error: you cannot specify '--inline' and '--out' at the same time");
		exit(1);
	}
	if (!path) {
		path = "-";
	}
	if (inline && path == "-") {
		stderr.writeln("error: you cannot specify '--inline' and read from stdin");
		exit(1);
	}

	File infile, outfile;
	if (inline) {
		copy(path, path ~ ".bak");
		infile = File(path ~ ".bak");
	} else if (path == "-") {
		infile = stdin;
	} else {
		infile = File(path);
	}

	if (inline)
		outfile = File(path, "w");
	else if (output)
		outfile = File(output, "w");
	else
		outfile = stdout;

	string softEnd = null;
	Import[] matches;
	foreach (line; infile.byLine(Yes.keepTerminator)) {
		auto match = matchFirst(line, pattern);
		if (!match.empty) { // is import
			if (softEnd) {
				if (!matches)
					outfile.write(softEnd);
				softEnd = null;
			}

			Import im;
			if (match[4]) {
				im.name = Identifier(match[3].idup, match[4].idup);
			} else {
				im.name = Identifier(match[3].idup);
			}
			im.begin = match[1].idup;
			im.end = match[6].idup;

			if (match[2] == "static")
				im.static_ = true;
			else if (match[2] == "public")
				im.public_ = true;

			if (match[5]) {
				foreach (id; match[5][1 .. $].split(",")) {
					if (auto pair = id.idup.findSplit("=")) { // has alias
						im.idents ~= Identifier(pair[0].strip, pair[2].strip);
					} else {
						im.idents ~= Identifier(id.idup.strip);
					}
				}
				im.idents.sort!((a, b) => a.sortBy < b.sortBy);
			}
			matches ~= im;
		} else {
			if (!softEnd && line.stripLeft == "") {
				softEnd = line.idup;
			} else {
				if (matches) {
					matches.sort!((a, b) => a.name.sortBy < b.name.sortBy);
					foreach (m; matches) {
						outfile.write(m.begin);
						if (m.public_)
							outfile.write("public ");
						if (m.static_)
							outfile.write("static ");
						if (m.name.hasAlias) {
							outfile.writef("import %s = %s", m.name.original, m.name.alias_);
						} else {
							outfile.write("import " ~ m.name.original);
						}
						foreach (i, ident; m.idents) {
							auto begin = i == 0 ? " : " : ", ";
							if (ident.hasAlias) { // hasAlias
								outfile.writef("%s%s = %s", begin, ident.original, ident.alias_);
							} else {
								outfile.write(begin ~ ident.original);
							}
						}
						outfile.writef(";%s", m.end);
					}

					matches = [];
				}
				if (softEnd) {
					outfile.write(softEnd);
					softEnd = null;
				}
				outfile.write(line);
			}
		}
	}

	infile.close();

	if (inline && !keep)
		remove(path ~ ".bak");

	outfile.close();
}
