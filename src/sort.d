module importsort.sort;

import std.algorithm : findSplit, remove, sort;
import std.array : split;
import std.file : DirEntry, rename;
import std.functional : unaryFun;
import std.range : ElementType;
import std.regex : ctRegex, matchFirst;
import std.stdio : File, stderr;
import std.string : strip, stripLeft;
import std.traits : isIterable;
import std.typecons : Yes;

/// the pattern to determinate a line is an import or not
enum PATTERN = ctRegex!`^(\s*)(?:(public|static)\s+)?import\s+(?:(\w+)\s*=\s*)?([a-zA-Z._]+)\s*(:\s*\w+(?:\s*=\s*\w+)?(?:\s*,\s*\w+(?:\s*=\s*\w+)?)*)?\s*;[ \t]*([\n\r]*)$`;

/// configuration for sorting imports
struct SortConfig {
	/// won't format the line, keep it as-is
	bool keepLine = false;

	/// sort by attributes (public/static first)
	bool byAttribute = false;

	/// sort by binding instead of the original
	bool byBinding = false;

	/// print interesting messages (TODO)
	bool verbose = false;

	/// merges imports of the same source
	bool merge = false;
}

/// helper-struct for identifiers and its bindings
struct Identifier {
	/// SortConfig::byBinding
	bool byBinding;

	/// the original e. g. 'std.stdio'
	string original;

	/// the binding (alias) e. g. 'io = std.stdio'
	string binding;

	/// wether this import has a binding or not
	@property
	bool hasBinding() {
		return binding != null;
	}

	/// the string to sort
	string sortBy() {
		if (byBinding)
			return hasBinding ? binding : original;
		else
			return original;
	}
}

/// the import statement description
struct Import {
	/// SortConfig::byAttribute
	bool byAttribute;

	/// the original line (is `null` if merges)
	string line;

	/// is a public-import
	bool public_;

	/// is a static-import
	bool static_;

	/// origin of the import e. g. `import std.stdio : ...;`
	Identifier name;

	/// symbols of the import e. g. `import ... : File, stderr, in = stdin;`
	Identifier[] idents;

	/// spaces before the import (indentation)
	string begin;

	/// the newline
	string end;

	/// the string to sort
	string sortBy() {
		if (byAttribute && (public_ || static_))
			return '\0' ~ name.sortBy;
		return name.sortBy;
	}
}

/// write import-statements to `outfile` with `config`
void writeImports(File outfile, SortConfig config, Import[] matches) {
	if (!matches)
		return;

	if (config.merge) {
		for (int i = 0; i < matches.length; i++) {
			for (int j = i + 1; j < matches.length; j++) {
				if (matches[i].name.original == matches[j].name.original
					&& matches[i].name.binding == matches[j].name.binding) {

					matches[i].line = null;
					matches[i].idents ~= matches[j].idents;
					matches = matches.remove(j);
					j--;
				}
			}
		}
	}

	matches.sort!((a, b) => a.sortBy < b.sortBy);
	bool first;

	foreach (m; matches) {
		if (config.keepLine && m.line.length > 0) {
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
			first = true;
			foreach (ident; m.idents) {
				auto begin = first ? " : " : ", ";
				first = false;
				if (ident.hasBinding) { // hasBinding
					outfile.writef("%s%s = %s", begin, ident.binding, ident.original);
				} else {
					outfile.write(begin ~ ident.original);
				}
			}
			outfile.writef(";", m.end);
		}
	}
}

/// sort imports of an entry (file) (entries: DirEntry[])
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

/// raw-implementation of sort file (infile -> outfile)
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
