module importsort.sort;

import std.algorithm : findSplit, sort;
import std.array : split;
import std.file : DirEntry, rename;
import std.functional : unaryFun;
import std.range : ElementType;
import std.regex : ctRegex, matchFirst;
import std.stdio : File, stderr;
import std.string : strip, stripLeft;
import std.traits : isIterable;
import std.typecons : Yes;

enum PATTERN = ctRegex!`^(\s*)(?:(public|static)\s+)?import\s+(?:(\w+)\s*=\s*)?([a-zA-Z._]+)\s*(:\s*\w+(?:\s*=\s*\w+)?(?:\s*,\s*\w+(?:\s*=\s*\w+)?)*)?\s*;[ \t]*([\n\r]*)$`;

struct SortConfig {
	bool keepLine = false;

	bool byAttribute = false;
	bool byBinding = false;
	bool verbose = false;
}

struct Identifier {
	bool byBinding;
	string original;
	string binding;

	string sortBy() {
		if (byBinding)
			return hasBinding ? binding : original;
		else
			return original;
	}

	bool hasBinding() {
		return binding != null;
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
			if (m.name.hasBinding) {
				outfile.writef("import %s = %s", m.name.binding, m.name.original);
			} else {
				outfile.write("import " ~ m.name.original);
			}
			foreach (i, ident; m.idents) {
				auto begin = i == 0 ? " : " : ", ";
				if (ident.hasBinding) { // hasBinding
					outfile.writef("%s%s = %s", begin, ident.binding, ident.original);
				} else {
					outfile.write(begin ~ ident.original);
				}
			}
			outfile.writef(";%s", m.end);
		}
	}
}

void sortImports(alias P = "true", R)(R entries, SortConfig config)
		if (isIterable!R && is(ElementType!R == DirEntry)) {
	alias postFunc = unaryFun!P;

	File infile, outfile;
	foreach (entry; entries) {
		stderr.writef("\033[34msorting \033[0;1m%s\033[0m\n", entry.name);

		infile = File(entry.name);
		outfile = File(entry.name ~ ".new", "w");

		sortImports(infile, outfile, config);

		infile.close();
		outfile.close();

		rename(entry.name ~ ".new", entry.name);

		cast(void) postFunc(entry.name);
	}
}

void sortImports(File infile, File outfile, SortConfig config) {
	string softEnd = null;
	Import[] matches;

	foreach (line; infile.byLine(Yes.keepTerminator)) {
		auto linestr = line.idup;
		if (auto match = linestr.matchFirst(PATTERN)) { // is import
			if (softEnd) {
				if (!matches)
					outfile.write(softEnd);
				softEnd = null;
			}

			auto im = Import(config.byAttribute, linestr);
			if (match[3]) {
				im.name = Identifier(config.byBinding, match[4], match[3]);
			} else {
				im.name = Identifier(config.byBinding, match[4]);
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
						im.idents ~= Identifier(config.byBinding, pair[2].strip, pair[0].strip);
					} else {
						im.idents ~= Identifier(config.byBinding, id.strip);
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
