// (c) 2022 Friedel Schon <derfriedmundschoen@gmail.com>

module importsort;

import core.stdc.stdlib : exit;
import std.algorithm : findSplit, map, sort;
import std.array : array;
import std.file : rename;
import std.regex : ctRegex, matchFirst;
import std.stdio : File, stderr, stdin, stdout;
import std.string : format, indexOf, split, strip, stripLeft;
import std.typecons : Tuple, Yes, tuple;

struct Identifier {
	bool byOriginal;
	string original;
	string alias_;

	string sortBy() {
		if (byOriginal)
			return original;
		else
			return hasAlias ? alias_ : original;
	}

	bool hasAlias() {
		return alias_ != null;
	}
}

struct Import {
	bool byAttribute;
	string line;

	bool public_;
	bool static_;
	Identifier name;
	Identifier[] idents;
	string begin;
	string end;

	string sortBy() {
		if (byAttribute && (public_ || static_))
			return '\0' ~ name.sortBy;
		return name.sortBy;
	}
}

enum VERSION = "0.1.0";

enum pattern = ctRegex!`^(\s*)(?:(public|static)\s+)?import\s+(?:(\w+)\s*=\s*)?([a-zA-Z._]+)\s*(:\s*\w+(?:\s*=\s*\w+)?(?:\s*,\s*\w+(?:\s*=\s*\w+)?)*)?\s*;[ \t]*([\n\r]*)$`;

enum help = "importsort-d v" ~ VERSION ~ "

Usage: importsort-d [-i [-k]] [-o <output>] [-r] [-s] [-w [-i <msec>]] <input...>
  <input> can be set to '-' to read from stdin

Options:
  -k, --keep ............ keeps the line as-is instead of formatting
  -i, --inline .......... writes to the input
  -o, --out <path> ...... writes to `path` instead of stdout

  -a, --attribute ....... public and static imports first
  -r, --original ........ sort by original not by binding

  -h, --help ............ prints this message
  -v, --verbose ......... prints useful messages";

struct SortConfig {
	bool keepLine = false;
	bool byAttribute = false;
	bool byOriginal = false;
}

void writeImports(File outfile, SortConfig config, Import[] matches) {
	if (!matches)
		return;

	matches.sort!((a, b) => a.sortBy < b.sortBy);
	foreach (m; matches) {
		if (config.keepLine) {
			outfile.write(m.line);
		} else {
			outfile.write(m.begin);
			if (m.public_)
				outfile.write("public ");
			if (m.static_)
				outfile.write("static ");
			if (m.name.hasAlias) {
				outfile.writef("import %s = %s", m.name.alias_, m.name.original);
			} else {
				outfile.write("import " ~ m.name.original);
			}
			foreach (i, ident; m.idents) {
				auto begin = i == 0 ? " : " : ", ";
				if (ident.hasAlias) { // hasAlias
					outfile.writef("%s%s = %s", begin, ident.alias_, ident.original);
				} else {
					outfile.write(begin ~ ident.original);
				}
			}
			outfile.writef(";%s", m.end);
		}
	}
}

void sortImports(SortConfig config, File infile, File outfile) {
	string softEnd = null;
	Import[] matches;

	foreach (line; infile.byLine(Yes.keepTerminator)) {
		auto linestr = line.idup;
		if (auto match = matchFirst(linestr, pattern)) { // is import
			if (softEnd) {
				if (!matches)
					outfile.write(softEnd);
				softEnd = null;
			}

			auto im = Import(config.byAttribute, linestr);
			if (match[3]) {
				im.name = Identifier(config.byOriginal, match[4], match[3]);
			} else {
				im.name = Identifier(config.byOriginal, match[4]);
			}
			im.begin = match[1];
			im.end = match[6];

			if (match[2] == "static")
				im.static_ = true;
			else if (match[2] == "public")
				im.public_ = true;

			if (match[5]) {
				foreach (id; match[5][1 .. $].split(",")) {
					if (auto pair = id.findSplit("=")) { // has alias
						im.idents ~= Identifier(config.byOriginal, pair[2].strip, pair[0].strip);
					} else {
						im.idents ~= Identifier(config.byOriginal, id.strip);
					}
				}
				im.idents.sort!((a, b) => a.sortBy < b.sortBy);
			}
			matches ~= im;
		} else {
			if (!softEnd && linestr.stripLeft == "") {
				softEnd = linestr;
			} else {
				if (matches) {
					outfile.writeImports(config, matches);
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
	outfile.writeImports(config, matches);
}

void main(string[] args) {
	SortConfig config;
	bool inline = false;
	string output = null;
	string path = null;

	bool nextout = false;

	foreach (arg; args[1 .. $]) {
		if (nextout) {
			output = arg;
			nextout = false;
		}
		if (arg == "--help" || arg == "-h") {
			stdout.writeln(help);
			return;
		} else if (arg == "--keep" || arg == "-k") {
			config.keepLine = true;
		} else if (arg == "--attribute" || arg == "-a") {
			config.byAttribute = true;
		} else if (arg == "--inline" || arg == "-i") {
			inline = true;
		} else if (arg == "--original" || arg == "-r") {
			config.byOriginal = true;
		} else if (arg == "--out" || arg == "-o") {
			if (output != null) {
				stderr.writeln("error: output already specified");
				stderr.writeln(help);
				exit(1);
			}
			nextout = true;
		} else if (arg[0] == '-') {
			stderr.writef("error: unknown option '%s'\n", arg);
			stderr.writeln(help);
			exit(1);
		} else {
			if (path != null) {
				stderr.writeln("error: input already specified");
				stderr.writeln(help);
				exit(1);
			}
			path = arg;
		}
	}
	if (output != null && output == path) {
		stderr.writeln("error: input and output cannot be the same; use '--inline'");
		stderr.writeln(help);
		exit(1);
	}
	if (inline && output != null) {
		stderr.writeln("error: you cannot specify '--inline' and '--out' at the same time");
		stderr.writeln(help);
		exit(1);
	}
	if (!path) {
		path = "-";
	}
	if (inline && path == "-") {
		stderr.writeln("error: you cannot specify '--inline' and read from stdin");
		stderr.writeln(help);
		exit(1);
	}

	File infile, outfile;
	if (inline) {
		infile = File(path);
	} else if (path == "-") {
		infile = stdin;
	} else {
		infile = File(path);
	}

	if (inline) {
		outfile = File(path ~ ".new", "w");
		scope (exit)
			rename(path ~ ".new", path);
	} else if (output) {
		outfile = File(output, "w");
	} else {
		outfile = stdout;
	}

	sortImports(config, infile, outfile);

	infile.close();
	outfile.close();
}
