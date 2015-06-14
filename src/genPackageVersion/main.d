module genPackageVersion.main;

import std.algorithm;
import std.array;
import std.getopt;
import std.json;
import std.process;
import std.regex;
import std.stdio;

import scriptlike.only;

import genPackageVersion.packageVersion;

immutable helpBanner = (
`gen-package-version `~packageVersion~`
<https://github.com/Abscissa/gen-package-version>
-------------------------------------------------
Generates a D module with version information automatically-detected
from git and (optionally) dub. This generated D file is automatically
added to .gitignore if necessary (unless using --no-ignore-file).

It is recommended to run this via DUB's preGenerateCommands by adding the
following lines to your project's dub.json:

	"dependencies": {
		"gen-package-version": "~>0.9.0"
	},
	"preGenerateCommands":
		["dub run gen-package-version -- your.package.name --src=path/to/src"],

USAGE:
gen-package-version [options] your.package.name --src=path/to/src
gen-package-version [options] your.package.name --dub

EXAMPLES:
gen-package-version foo.bar --src=source/dir
	Generates module "foo.bar.packageVersion" in the file:
		source/dir/foo/bar/packageVersion.d
	
	Access the info from your program via:

	import foo.bar.packageVersion;
	writeln("Version: ", packageVersion);
	writeln("Built on: ", packageTimestamp);

gen-package-version foo.bar --dub
	Generates module "foo.bar.packageVersion" in the file:
		(your_src_dir)/foo/bar/packageVersion.d

	Where (your_src_dir) above is auto-detected via "dub describe".
	The first path in "importPaths" is assumed to be (your_src_dir).
	
	Additional info is available when using --dub:

	writeln("This program's name is ", packageName);

OPTIONS:`).replace("\t", "    ");

enum LogLevel
{
	silent,
	quiet,
	normal,
	verbose,
	trace,
}
auto logLevel = LogLevel.normal;

void logQuiet  (T...)(T args) { log!(LogLevel.quiet)(args); }
void logNormal (T...)(T args) { log!(LogLevel.normal)(args); }
void logVerbose(T...)(T args) { log!(LogLevel.verbose)(args); }
void logTrace  (T...)(T args) { log!(LogLevel.trace)(args); }
void log(LogLevel minimumLogLevel, T...)(T args)
{
	static assert(minimumLogLevel != LogLevel.silent);
	
	if(logLevel >= minimumLogLevel)
		writeln(args);
}

string outPackageName = null;
string outModuleName = "packageVersion";
string projectSourcePath = null;
bool useDub = false;
bool noIgnoreFile = false;
bool dryRun = false;

// Returns: Should program execution continue?
bool doGetOpt(ref string[] args)
{
	immutable usageHint = "For usage, run: gen-package-version --help";
	bool showVersion;
	
	try
	{
		auto helpInfo = args.getopt(
			"dub",            "        Use dub. May be slightly slower, but allows --src to be auto-detected, and adds extra info to the generated module.", &useDub,
			"s|src",          "= VALUE Path to source files. Required unless --dub is used.", &projectSourcePath,
			"module",         "= VALUE Override the module name. Default: packageVersion", &outModuleName,
			"no-ignore-file", "        Do not attempt to update .gitignore", &noIgnoreFile,
			"dry-run",        "        Dry run. Don't actually write or modify any files. Implies --verbose",
				{ logLevel = LogLevel.verbose; scriptlikeEcho = true; dryRun = true;},
			//"silent",         "        Silence all non-error output",           { logLevel = LogLevel.silent; },
			"q|quiet",        "        Quiet mode",                             { logLevel = LogLevel.quiet; },
			"v|verbose",      "        Verbose mode",                           { logLevel = LogLevel.verbose; scriptlikeEcho = true; },
			"trace",          "        Extremely verbose mode (for debugging)", { logLevel = LogLevel.trace; scriptlikeEcho = true; },
			//"log-level",      "        Verbosity level: --log-level=silent|quiet|normal|verbose|trace", &logLevel,
			"version",        "        Show this program's version number and exit", &showVersion,
		);

		if(helpInfo.helpWanted)
		{
			defaultGetoptPrinter(helpBanner, helpInfo.options);
			return false;
		}
	}
	catch(GetOptException e)
		fail(e.msg, "\n", usageHint);
	
	if(showVersion)
	{
		writeln(packageVersion);
		return false;
	}
	
	failEnforce(args.length == 2 && !args[1].empty, "Missing package name\n", usageHint);
	outPackageName = args[1];

	failEnforce(projectSourcePath || useDub,
		"Missing --src= (Alternatively, you could use --dub to auto-detect --src=)\n", usageHint);

	return true;
}

version(unittest) void main() {} else
void main(string[] args)
{
	// Handle args
	if(!doGetOpt(args))
		return;

	try
		generatePackageVersion();
	catch(ErrorLevelException e)
		fail(e.msg);
		
	return;
}

void generatePackageVersion()
{
	import std.datetime;
	import std.file : exists;
	import std.path : buildPath, dirName;
	
	// Grab basic info
	auto versionStr = getVersionStr();
	logTrace("versionStr: ", versionStr);
	
	auto now = Clock.currTime;
	
	// Generate dub extras
	string dubExtras;
	if(useDub)
		dubExtras = generateDubExtras(projectSourcePath);
	
	// Generate D source code
	auto dModule =
`/// Generated at `~now.toString()~`
/// by gen-package-version `~packageVersion~`
/// <https://github.com/Abscissa/gen-package-version>
module `~outPackageName~`.`~outModuleName~`;

/// Version of this package, obtained via "git describe"
enum packageVersion = "`~versionStr~`";

/// Timestamp of when this packageVersion module was generated,
/// as an ISO Ext string. Get a SysTime from this via:
/// std.datetime.fromISOExtString(packageTimestamp)
enum packageTimestamp = "`~now.toISOExtString()~`";
`~dubExtras;
	logTrace("--------------------------------------");
	logTrace(dModule);
	logTrace("--------------------------------------");
	
	// Determine output filepath
	auto packagePath = outPackageName.replace(".", dirSeparator);
	auto modulePath  = outModuleName .replace(".", dirSeparator);
	auto outPath = buildPath(projectSourcePath, packagePath, modulePath) ~ ".d";
	logTrace("outPath: ", outPath);
	
	// Write the file
	auto outDir = std.path.dirName(outPath);
	failEnforce(exists(outDir), "Output directory doesn't exist: ", outDir);
	failEnforce(std.file.isDir(outDir), "Output directory isn't a directory: ", outDir);

	logVerbose("Saving to ", outPath);
	if(!dryRun)
	{
		try
			std.file.write(outPath, dModule);
		catch(FileException e)
			fail(e.msg);
	}
	
	// Check for .gitignore
	if(!noIgnoreFile)
		addToGitIgnore(outPath);
}

string getVersionStr()
{
	import std.string : strip;

	auto result = tryRunCollect("git describe");
	if(result.status)
		return "unknown-ver";
	else
		return result.output.strip();
}

// Auto-detects srcDir if srcDir doesn't already have a value.
// Returns D source code to be appended to the output file.
string generateDubExtras(ref string srcDir)
{
	auto jsonRoot = parseJSON( runCollect("dub describe") );
	auto rootPackageName = jsonRoot["rootPackage"].str;
	logTrace("rootPackageName: ", rootPackageName);
	
	auto packageInfo = jsonRoot.getPackageInfo(rootPackageName);
	auto targetName = packageInfo["targetName"].str;

	if(!srcDir)
	{
		// Auto-detect srcDir
		auto importPaths = packageInfo["importPaths"].array.map!(val => val.str).array();
		logTrace("importPaths: ", importPaths);
		
		failEnforce(importPaths.length > 0,
			"Unable to autodetect source directory: Import path not found in 'dub describe'.");
		
		srcDir = importPaths[0];
		logNormal("Detected source directory: ", srcDir);
	}
	
	return
`
/// DUB package name of this project.
/// Ie, dub.json's "name" field.
enum packageName = "`~rootPackageName~`";

/// Name of this project's target binary, minus extensions and prefixes.
/// Ie, dub.json's "targetName" field.
///
/// Note that depending on your needs, it may be better to
/// use std.file.thisExePath()
enum packageTargetName = "`~targetName~`";
`;
}

JSONValue getPackageInfo(JSONValue dubInfo, string packageName)
{
	auto packages = dubInfo["packages"].array;

	foreach(pack; packages)
	if(pack["name"].str)
		return pack;
	
	fail("Package '"~packageName~"' not found. Received bad data from 'dub describe'.");
	assert(0);
}

void addToGitIgnore(string path)
{
	immutable ignoreFileName = ".gitignore";
	// Normalize to the style of git's homeland, Linux.
	// Don't worry, this works on Windows just fine.
	path = path.replace("\\", "/");
	
	// Doesn't already exist? Create it.
	if(!std.file.exists(ignoreFileName))
	{
		logVerbose("No existing ", ignoreFileName, " file. Creating it.");
		if(!dryRun)
			std.file.write(ignoreFileName, path~"\n");

		return;
	}
	
	// Make sure it's actually a file
	if(!std.file.isFile(ignoreFileName))
	{
		logVerbose("Strange, ", ignoreFileName, " exists but isn't a file. Not updating it.");
		return; // Not a file? Don't even bother with it.
	}
	
	// Is 'path' already in the ignore file?
	//import std.string : strip;
	auto isAlreadyInFile =
		File(ignoreFileName)
		.byLine()
		.map!(std.string.strip)()  // Get rid of any trailing \r byLine might have left us on Windows
		.map!(a => a.replace("\\", "/"))
		.canFind(path);
	
	// Append 'path' to the ignore file
	if(!isAlreadyInFile)
	{
		logVerbose("Path '", path, "' not found in ", ignoreFileName, " file. Adding it.");

		if(!dryRun)
		{
			auto file = File(ignoreFileName, "a+");
			scope(exit) file.close();
	
			// Everything on Windows handles \n just fine, plus git is
			// heavily Linux-oriented so \n is more appropriate.
			file.rawWrite("\n"); // Just in case there isn't already a trailing newline
			file.rawWrite(path);
			file.rawWrite("\n");
		}
	}
	else
		logVerbose("Path '", path, "' is already found in ", ignoreFileName, " file.");
}
