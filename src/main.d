// (c) 2022 Friedel Schon <derfriedmundschoen@gmail.com>

module source.main;

import core.stdc.stdlib : exit;
import std.algorithm : map, sort;
import std.array : array;
import std.file : copy, remove;
import std.range : empty;
import std.regex : ctRegex, matchFirst;
import std.stdio : File, stderr, stdin, stdout;
import std.string : format, split, strip, stripLeft;
import std.typecons : Yes;

struct Import {
	string name;
	string[] indents;

	string begin;
	string end;
}

const pattern = ctRegex!`^([ \t]*)import[ \t]+([a-zA-Z._]+)[ \t]*(:[ \t]*\w+(?:[ \t]*,[ \t]*\w+)*)?[ \t]*;[ \t]*([\n\r]*)$`;

const help = (string arg0) => "Usage: %s [options] [path]
  <path> can be ommitted or set to '-' to read from stdin

Options:
  -k, --keep ....... keeps a backup if using '--inline'
  -i, --inline ..... changes the input
  -o, --out <path> . writes to `path` instead of stdout".format(arg0);

void main(string[] args) {
	bool inline = false;
	bool keep = false;
	string output = null;
	string path = null;

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
				if (matches.empty)
					outfile.write(softEnd);
				softEnd = null;
			}

			string[] idents;
			if (match[3]) {
				idents = match[3][1 .. $].split(",").map!(x => x.idup.strip).array;
				idents.sort();
			}
			matches ~= Import(match[2].idup, idents, match[1].idup, match[4].idup);
		} else {
			if (!softEnd && line.stripLeft == "") {
				softEnd = line.idup;
			} else {
				if (!matches.empty) {
					matches.sort!((a, b) => a.name < b.name);
					foreach (m; matches) {
						outfile.writef("%simport %s", m.begin, m.name);
						foreach (i, ident; m.indents) {
							auto begin = i == 0 ? " : " : ", ";
							outfile.write(begin ~ ident);
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
