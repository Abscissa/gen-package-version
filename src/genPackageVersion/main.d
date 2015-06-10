module genPackageVersion.main;

import std.algorithm;
import std.array;
import std.file;
import std.getopt;
import std.json;
import std.process;
import std.regex;
import std.stdio;

import scriptlike.fail;
import scriptlike.path;

import genPackageVersion.packageVersion;

immutable helpBanner = (
`genPackageVersion - <https://github.com/Abscissa/genPackageVersion>
Version: `~packageVersion~`
-------------------------------------------------------------------
Generates a D module with version information automatically-detected
from git and dub.

This automatically detects your source directory via DUB (if your project's
dub.json lists more than directory in "importPaths", then this
will use the first one). Within your main source directory, 

It is recommended to run this via DUB's preGenerateCommands in your dub.json:
{
	"name": "my-project",
	"dependencies": {
		"genPackageVersion": "~>0.9.0"
	},
	"preGenerateCommands-posix": [
		"$GENPACKAGEVERSION_PACKAGE_DIR/bin/genPackageVersion --src=source"
	]
	"preGenerateCommands-windows": [
		"$GENPACKAGEVERSION_PACKAGE_DIR\bin\genPackageVersion --src=source"
	]
}

USAGE:
genPackageVersion [options] your.package.name --src=path/to/src
genPackageVersion [options] your.package.name --dub

EXAMPLES:
genPackageVersion foo.bar --src=source/dir
	Generates module "foo.bar.packageVersion" in
	the file: source/dir/foo/bar/packageVersion.d
	
	Access the info from your program via:

	import foo.bar.packageVersion;
	writeln("Version: ", packageVersion);
	writeln("Built on: ", packageTimestamp);

genPackageVersion foo.bar --dub
	Generates module "foo.bar.packageVersion" in
	the file: (your_src_dir)/foo/bar/packageVersion.d
	Where (your_src_dir) is auto-detected via "dub describe".
	
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
	immutable usageHint = "For usage, run: genPackageVersion --help";
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
		fail(e.msg ~ "\n" ~ usageHint);
	
	if(showVersion)
	{
		writeln(packageVersion);
		return false;
	}
	
	if(args.length != 2 || args[1].empty)
		fail("Missing package name\n" ~ usageHint);
	
	outPackageName = args[1];

	if(!projectSourcePath && !useDub)
		fail("Missing --src= (Alternatively, you could use --dub to auto-detect --src=)\n" ~ usageHint);

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
	import std.path : buildPath;
	
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
/// by genPackageVersion <https://github.com/Abscissa/genPackageVersion>
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
	auto outDir = dirName(outPath);
	if(!std.file.exists(outDir))
		fail("Output directory doesn't exist: " ~ outDir);
	
	if(!std.file.isDir(outDir))
		fail("Output directory isn't a directory: " ~ outDir);

	logVerbose("Saving to ", outPath);
	if(!dryRun)
	{
		try
			std.file.write(outPath, dModule);
		catch(FileException e)
			fail(e.msg);
	}
}

string getVersionStr()
{
	import std.string : strip;

	auto result = tryRunCollect("git describe");
	if(result.status)
		return "unknown";
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
		
		if(importPaths.length == 0)
			fail("Unable to autodetect source directory: Import path not found in 'dub describe'.");
		
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

// This stuff should be added to scriptlike:

///runCollect
string runCollect()(string command)
{
	auto result = tryRunCollect(command);
	if(result.status != 0)
		throw new ErrorLevelException(result.status, command);

	return result.output;
}

///ditto
string runCollect(C)(PathT!C workingDirectory, string command)
{
	auto saveDir = getcwd();
	workingDirectory.chdir();
	scope(exit) saveDir.chdir();
	
	return runCollect(command);
}

/// tryRunCollect: Returns same tuple as std.process.executeShell:
/// std.typecons.Tuple!(int, "status", string, "output")
auto tryRunCollect()(string command)
{
	//echoCommand(command);

	if(scriptlikeDryRun)
		return std.typecons.Tuple!(int, "status", string, "output")(0, null);
	else
		return executeShell(command);
}

///ditto
auto tryRunCollect(C)(PathT!C workingDirectory, string command)
{
	auto saveDir = getcwd();
	workingDirectory.chdir();
	scope(exit) saveDir.chdir();
	
	return tryRunCollect(command);
}
