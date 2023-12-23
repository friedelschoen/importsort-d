// (c) 2022-2023 Friedel Schon <derfriedmundschoen@gmail.com>

module importsort.sort;

import importsort.main : SortConfig;
import std.algorithm : findSplit, remove, sort;
import std.algorithm.comparison : equal;
import std.array : split;
import std.conv : to;
import std.file : DirEntry, rename;
import std.functional : unaryFun;
import std.range : ElementType;
import std.regex : ctRegex, matchFirst;
import std.stdio : File, stderr;
import std.string : strip, stripLeft;
import std.traits : isIterable;
import std.typecons : Nullable, Yes, nullable;
import std.uni : asLowerCase;

/// the pattern to determinate a line is an import or not
enum PATTERN = ctRegex!`^(\s*)(?:(public|static)\s+)?import\s+(?:(\w+)\s*=\s*)?([a-zA-Z._]+)\s*(:\s*\w+(?:\s*=\s*\w+)?(?:\s*,\s*\w+(?:\s*=\s*\w+)?)*)?\s*;[ \t]*([\n\r]*)$`;

/// helper-struct for identifiers and its bindings
struct Identifier {
	/// SortConfig::byBinding
	bool byBinding;

	/// the original e. g. 'std.stdio'
	string original;

	/// the binding (alias) e. g. 'io = std.stdio'
	string binding;

	/// wether this import has a binding or not
	@property bool hasBinding() {
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

bool less(SortConfig config, string a, string b) {
	return config.ignoreCase ? a.asLowerCase.to!string < b.asLowerCase.to!string : a < b;
}

void sortMatches(SortConfig config, Import[] matches) {
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

	matches.sort!((a, b) => less(config, a.sortBy, b.sortBy));

	foreach (m; matches)
		m.idents.sort!((a, b) => less(config, a.sortBy, b.sortBy));
}

bool checkChanged(SortConfig config, Import[] matches) {
	if (!matches)
		return false;

	auto original = matches.dup;

	sortMatches(config, matches);

	return !equal(original, matches);
}

/// write import-statements to `outfile` with `config`
void writeImports(File outfile, SortConfig config, Import[] matches) {
	if (!matches)
		return;

	sortMatches(config, matches);

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
			outfile.writef(";%s", m.end);
		}
	}
}

/// sort imports of an entry (file) (entries: DirEntry[])
void sortImports(R)(R entries, SortConfig config)
		if (isIterable!R && is(ElementType!R == DirEntry)) {

	File infile, outfile;
	foreach (entry; entries) {
		infile = File(entry.name);

		if (sortImports(config, infile, Nullable!(File).init)) { // is changed
			infile.seek(0);
			outfile = File(entry.name ~ ".new", "w");
			sortImports(config, infile, nullable(outfile));
			rename(entry.name ~ ".new", entry.name);
			stderr.writef("\033[34msorted    \033[0;1m%s\033[0m\n", entry.name);
			outfile.close();
		} else {
			stderr.writef("\033[33munchanged \033[0;1m%s\033[0m\n", entry.name);
		}

		infile.close();
	}
}

bool sortImports(SortConfig config, File infile, Nullable!File outfile) {
	string softEnd = null;
	Import[] matches;

	foreach (line; infile.byLine(Yes.keepTerminator)) {
		auto linestr = line.idup;
		if (auto match = linestr.matchFirst(PATTERN)) { // is import
			if (softEnd) {
				if (!matches && !outfile.isNull)
					outfile.get().write(softEnd);
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
			}
			matches ~= im;
		} else {
			if (!softEnd && linestr.stripLeft == "") {
				softEnd = linestr;
			} else {
				if (matches) {
					if (!outfile.isNull)
						outfile.get().writeImports(config, matches);
					else if (checkChanged(config, matches))
						return true;

					matches = [];
				}
				if (softEnd) {
					if (!outfile.isNull)
						outfile.get().write(softEnd);
					softEnd = null;
				}
				if (!outfile.isNull)
					outfile.get().write(line);
			}
		}
	}

	// flush last imports

	if (!outfile.isNull)
		outfile.get().writeImports(config, matches);
	else if (checkChanged(config, matches))
		return true;

	return false;
}
