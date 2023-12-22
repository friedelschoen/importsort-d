// (c) 2022 Friedel Schon <derfriedmundschoen@gmail.com>

module importsort.main;
import importsort.sort : SortConfig;
import argparse : CLI;
import core.stdc.stdlib : exit;
import importsort.sort : Import, sortImports;
import std.array : replace;
import std.file : DirEntry, SpanMode, dirEntries, exists, isDir, isFile;
import std.functional : unaryFun;
import std.stdio : File, stderr, stdin, stdout;
import std.range : empty;
import std.string : endsWith;

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

int _main(SortConfig config) {
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
}

mixin CLI!(SortConfig).main!((config) { return _main(config); });
