// (c) 2022 Friedel Schon <derfriedmundschoen@gmail.com>

module test.main;

import core.stdc.stdlib : exit;
import core.thread : Thread;
import core.time : Duration = dur;
import std.algorithm : canFind, each, endsWith, filter, findSplit, map, sort;
import std.array : array, replace;
import std.conv : ConvException, parse;
import std.datetime : SysTime;
import std.file : DirEntry, SpanMode, dirEntries, exists, isDir, isFile, rename, timeLastModified;
import std.functional : unaryFun;
import std.range : ElementType, empty;
import std.regex : ctRegex, matchFirst;
import std.stdio : File, stderr, stdin, stdout;
import std.string : format, indexOf, split, strip, stripLeft;
import std.traits : isIterable;
import std.typecons : Tuple, Yes, tuple;

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

enum PATTERN = ctRegex!`^(\s*)(?:(public|static)\s+)?import\s+(?:(\w+)\s*=\s*)?([a-zA-Z._]+)\s*(:\s*\w+(?:\s*=\s*\w+)?(?:\s*,\s*\w+(?:\s*=\s*\w+)?)*)?\s*;[ \t]*([\n\r]*)$`;

enum BINARY = "importsort-d";
enum VERSION = "0.1.0";
enum HELP = import("help.txt")
		.replace("{binary}", BINARY)
		.replace("{version}", VERSION);

struct SortConfig {
	bool keepLine = false;
	bool byAttribute = false;
	bool byBinding = false;
	bool verbose = false;
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

DirEntry[] listEntries(alias F = "true")(string[] input, bool recursive) {
	alias filterFunc = unaryFun!F;

	DirEntry[] entries;

	foreach (path; input) {
		if (!exists(path)) {
			stderr.writef("error: '%s' does not exist\n", path);
			exit(1);
		} else if (isDir(path)) {
			foreach (entry; dirEntries(path, recursive ? SpanMode.depth : SpanMode.shallow)) {
				if (entry.isFile && entry.name.endsWith(".d") && filterFunc(entry.name))
					entries ~= entry;
			}
		} else if (isFile(path)) {
			if (!path.endsWith(".d")) {
				stderr.writef("error: '%s' is not a .d-file\n", path);
				exit(1);
			}
			if (filterFunc(path))
				entries ~= DirEntry(path);
		} else {
			stderr.writef("error: '%s' is not a file or directory\n", path);
			exit(1);
		}
	}
	return entries;
}

void main(string[] args) {
	SortConfig config;
	bool inline;
	string output;
	string[] input;
	bool watcher;
	bool watcherDelaySet;
	double watcherDelay = 0.1; // sec
	bool recursive;

	// -*- option parser -*-

	bool nextOutput;
	bool nextWatcherDelay;
	foreach (arg; args[1 .. $]) {
		if (nextOutput) {
			output = arg;
			nextOutput = false;
		} else if (nextWatcherDelay) {
			try {
				watcherDelay = parse!double(arg);
			} catch (ConvException) {
				stderr.writef("error: cannot parse delay '%s' to an integer\n", arg);
				exit(1);
			}
			watcherDelaySet = true;
			nextWatcherDelay = false;
		} else if (arg == "--help" || arg == "-h") {
			stdout.writeln(HELP);
			return;
		} else if (arg == "--verbose" || arg == "-v") {
			config.verbose = true;
		} else if (arg == "--keep" || arg == "-k") {
			config.keepLine = true;
		} else if (arg == "--attribute" || arg == "-a") {
			config.byAttribute = true;
		} else if (arg == "--binding" || arg == "-b") {
			config.byBinding = true;
		} else if (arg == "--inline" || arg == "-i") {
			inline = true;
		} else if (arg == "--recursive" || arg == "-r") {
			recursive = true;
			// TODO: --watch
			/*} else if (arg == "--watch" || arg == "-w") {
			watcher = true;
		} else if (arg == "--delay" || arg == "-d") {
			if (watcherDelaySet) {
				stderr.writeln("error: watcher-delay already specified");
				stderr.writeln(HELP);
				exit(1);
			}
			nextWatcherDelay = true;*/
		} else if (arg == "--output" || arg == "-o") {
			if (output != null) {
				stderr.writeln("error: output already specified");
				stderr.writeln(HELP);
				exit(1);
			}
			nextOutput = true;
		} else if (arg[0] == '-') {
			stderr.writef("error: unknown option '%s'\n", arg);
			stderr.writeln(HELP);
			exit(1);
		} else {
			input ~= arg;
		}
	}
	if (recursive && input.length == 0) {
		stderr.writeln("error: cannot use '--recursive' and specify no input");
		exit(1);
	}
	if (inline && input.length == 0) {
		stderr.writeln("error: cannot use '--inline' and read from stdin");
		exit(1);
	}
	if ((!inline || output.length > 0) && input.length > 0) {
		stderr.writeln("error: if you use inputs you must use '--inline'");
		exit(1);
	}
	// -*- operation -*-

	/*	if (watcher) {
		stderr.writeln("\033[1;34mwatching files...\033[0m");
		SysTime[string] lastModified;
		for (;;) {
			auto entries = listEntries!(x => x !in lastModified
					|| lastModified[x] != x.timeLastModified)(input, recursive);

			foreach (entry; entries) {
				lastModified[entry.name] = entry.timeLastModified;
			}
			entries.sortImports(config);
			Thread.sleep(Duration!"msecs"(cast(long) watcherDelay * 1000));
		}
	} else 
	*/
	if (input == null) {
		File outfile = (output == null) ? stdout : File(output);

		sortImports(stdin, outfile, config);
		if (output)
			outfile.close();
	} else {
		listEntries(input, recursive).sortImports(config);
	}
}
