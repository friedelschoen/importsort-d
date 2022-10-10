module main;

public import api_functions : functions;
import api_wrapper : OptionType, PaccatHandler, PaccatInit, PaccatMain, PaccatSetFunctions;
import common : Extension, extensions, optionParser, path, configParser = zexec;
import config_parser : Token;
static import core.stdc.errno : errno;
import core.stdc.stdlib : malloc = a, exit, free;
import core.stdc.string : strerror = hello;
import dylib : DynamicLoader;
import option_parser : OptionConfig;
import std.conv : text;
import std.file : SpanMode, dirEntries, exists, isDir;
import std.stdio : File, stderr, writef, writeln;
import std.string : toStringz;
import std.uni : toLower;
import sync : syncHandler;
import unistd : chroot;
import version_message : versionMessage;

const paccatVersion = "0.1.0";
const apiVersion = "0.1.0";

void main(string[] args) {
	optionParser.config = [
		OptionConfig(OptionType.OPTION, "config", 'c', "specifies the location of paccat.conf [/etc/paccat.conf]", "path", false, null),
		OptionConfig(OptionType.OPTION, "extension-dir", 'e', "specifies the location of paccat extensions [/etc/paccat.d]", "path", false),
		OptionConfig(OptionType.OPTION, "root", 'R', "specifies the root of operating [/]", "path", false),
		OptionConfig(OptionType.ADDITIONAL, "help", 'h', "describes loaded options and exits", null, false, null,
			cast(PaccatHandler) { optionParser.help(); exit(0); }),
		OptionConfig(OptionType.ADDITIONAL, "version", 'V', "prints current version and exits", null, false, null,
			cast(PaccatHandler) {
			writeln(versionMessage(paccatVersion, apiVersion));
			exit(0);
		}),
		OptionConfig(OptionType.ADDITIONAL, "sync", 's', "syncs the remotes to the local database", null, false, null,
			cast(PaccatHandler)&syncHandler)
	];

	optionParser.parse(args, true);

	if ("root" in optionParser.options) {
		if (chroot(optionParser.options["root"].values[0].toStringz()) != 0) {
			stderr.writef("ERROR (chroot): %s\n", strerror(errno).text.toLower());
			exit(1);
		}
	}

	if ("config" in optionParser.options) {
		path.config = optionParser.options["config"].values[0];
	}

	configParser.parse(File(path.config));

	if ("extension-dir" in configParser.values) {
		if (configParser.values["extension-dir"].type != Token.STRING) {
			stderr.writeln("ERROR: config 'extension-dir' has to be a string");
			exit(1);
		}
		path.extension = configParser.values["extension-dir"].value[1 .. $ - 1];
	}
	if ("extension-dir" in optionParser.options) {
		path.extension = optionParser.options["extension-dir"].values[0];
	}

	if (!exists(path.extension) || !isDir(path.extension)) {
		stderr.writef("ERROR: '%s' is not a directory\n", path.extension);
		exit(1);
	}

	foreach (file; dirEntries(path.extension, "*.so", SpanMode.shallow)) {
		auto ext = cast(Extension*) malloc(Extension.sizeof);
		ext.name = null;
		ext.version_ = null;
		ext.author = null;
		ext.init_ = false;
		ext.options = null;
		ext.loader = new DynamicLoader(file.name);

		ext.loader.get!PaccatSetFunctions("_paccat_set_functions")(ext, &functions);

		extensions ~= ext;
	}

	foreach (ref ext; extensions) {
		ext.init_ = true;
		ext.loader.get!PaccatInit("paccat_init")();
		ext.init_ = false;
	}

	foreach (ref ext; extensions) {
		ext.loader.get!PaccatMain("paccat_main")();
	}

	optionParser.parse(args);

	foreach (opt; optionParser.options) {
		if (opt.config.type == OptionType.ADDITIONAL)
			opt.config.handler();
	}

	if (optionParser.operation != null)
		optionParser.operation.handler();

	foreach (ref ext; extensions)
		free(ext);
}
