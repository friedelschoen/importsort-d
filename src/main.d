// (c) 2022 Friedel Schon <derfriedmundschoen@gmail.com>

module importsort.main;

import argparse;
import core.stdc.stdlib : exit;
import importsort.sort : Import, sortImports;
import std.array : replace;
import std.file : DirEntry, SpanMode, dirEntries, exists, isDir, isFile;
import std.functional : unaryFun;
import std.range : empty;
import std.stdio : File, stderr, stdin, stdout;
import std.string : endsWith;

/// current version (and something I always forget to update oops)
enum VERSION = "0.3.0";

/// configuration for sorting imports
@(Command("importsort-d").Description("Sorts dlang imports").Epilog("Version: v" ~ VERSION))
struct SortConfig {
	@(ArgumentGroup("Input/Output arguments")
			.Description(
				"Define in- and output behavior. Trailing arguments are considered input-files.")) {
		@(NamedArgument(["recursive", "r"]).Description("recursively search in directories"))
		bool recursive = false;

		@(NamedArgument(["inplace", "i"]).Description("writes to the input"))
		bool inplace = false;

		@(NamedArgument(["output", "o"]).Description("writes to `path` instead of stdout"))
		string output;
	}

	@(ArgumentGroup("Sorting arguments").Description("Tune import sorting algorithms")) {
		/// won't format the line, keep it as-is
		@(NamedArgument(["keep", "k"]).Description("keeps the line as-is instead of formatting"))
		bool keepLine = false;

		@(NamedArgument(["attribute", "a"]).Description("public and static imports first"))
		 /// sort by attributes (public/static first)
		bool byAttribute = false;

		@(NamedArgument(["binding", "b"]).Description("sorts by binding rather then the original"))
		 /// sort by binding instead of the original
		bool byBinding = false;

		@(NamedArgument(["merge", "m"]).Description("merge imports which uses same file"))
		 /// merges imports of the same source
		bool merge = false;

		/// ignore case when sorting
		@(NamedArgument(["ignore-case", "c"]).Description("ignore case when comparing elements"))
		bool ignoreCase = false;
	}

	string[] inputs;
}

/// list entries (`ls`) from all arguments
DirEntry[] listEntries(alias F = "true")(string[] input, bool recursive) {
	alias filterFunc = unaryFun!F;

	DirEntry[] entries;

	foreach (path; input) {
		if (!exists(path)) {
			stderr.writef("error: '%s' does not exist\n", path);
			exit(19);
		} else if (isDir(path)) {
			foreach (entry; dirEntries(path, recursive ? SpanMode.depth : SpanMode.shallow)) {
				if (entry.isFile && entry.name.endsWith(".d") && filterFunc(entry.name))
					entries ~= entry;
			}
		} else if (isFile(path)) {
			if (!path.endsWith(".d")) {
				stderr.writef("error: '%s' is not a .d-file\n", path);
				exit(11);
			}
			if (filterFunc(path))
				entries ~= DirEntry(path);
		} else {
			stderr.writef("error: '%s' is not a file or directory\n", path);
			exit(12);
		}
	}
	return entries;
}

mixin CLI!(SortConfig).main!((config, unparsed) {
	config.inputs = unparsed;

	if (config.recursive && config.inputs.empty) {
		stderr.writeln("error: cannot use '--recursive' and specify no input");
		exit(1);
	}
	if (config.inplace && config.inputs.empty) {
		stderr.writeln("error: cannot use inplace and read from stdin");
		exit(2);
	}
	if (!config.inputs.empty && (!config.inplace || !config.output.empty)) {
		stderr.writeln(
			"error: if you use inputs you must use inplace sorting or provide an output");
		exit(3);
	}

	if (config.inputs.empty) {
		auto outfile = config.output.empty ? stdout : File(config.output);
		sortImports(stdin, outfile, config);
	} else {
		listEntries(config.inputs, config.recursive).sortImports(config);
	}
	return 0;
});
