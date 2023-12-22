// (c) 2022 Friedel Schon <derfriedmundschoen@gmail.com>

module importsort.main;

import core.stdc.stdlib : exit;import importsort.sort : Import, SortConfig, sortImports;import std.array : replace;import std.conv : ConvException, parse;import std.file : DirEntry, SpanMode, dirEntries, exists, isDir, isFile;import std.functional : unaryFun;import std.stdio : File, stderr, stdin, stdout;import std.string : endsWith;
/// name of binary (for help)
enum BINARY = "importsort-d";

/// current version (and something I always forget to update oops)
enum VERSION = "0.3.0";

/// the help-message from `help.txt`
enum HELP = import("help.txt")
		.replace("{binary}", BINARY)
		.replace("{version}", VERSION);

/// list entries (`ls`) from all arguments
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

/// the main-function (nothing to explain)
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
		} else if (arg == "--merge" || arg == "-m") {
			config.merge = true;
		} else if (arg == "--ignoreCase" || arg == "-c") {
			config.ignoreCase = true;
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
