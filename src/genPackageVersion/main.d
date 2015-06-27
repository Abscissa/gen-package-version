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
from git or hg and (optionally) dub. This generated D file is automatically
added to .gitignore/.hgignore if necessary (unless using --no-ignore-file).

It is recommended to run this via DUB's preGenerateCommands by copy/pasting the
following lines into your project's dub.json:

	"dependencies": {
		"gen-package-version": "~>0.9.5"
	},
	"preGenerateCommands":
		["dub run gen-package-version -- your.package.name --root=$PACKAGE_DIR --src=path/to/src"]

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

gen-package-version foo.bar --src=source/dir --ddoc=ddoc/dir
	Same as above, but also generates a DDOC macro file:
		ddoc/dir/packageVersion.ddoc
	
	Which defines the macros: $(FOO_BAR_VERSION), $(FOO_BAR_TIMESTAMP)
	and $(FOO_BAR_TIMESTAMP_ISO).

gen-package-version foo.bar --dub
	Generates module "foo.bar.packageVersion" in the file:
		(your_src_dir)/foo/bar/packageVersion.d

	Where (your_src_dir) above is auto-detected via "dub describe".
	The first path in "importPaths" is assumed to be (your_src_dir).
	
	Additional info is available when using --dub:

	writeln("This program's name is ", packageName);

Note that even if --dub isn't used, gen-package-version might still run dub
anyway if detecting the version through git/hg fails (for example, if the
package is not in a VCS-controlled working directory, such as the case when
a package is downloaded via dub).

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
string rootPath = ".";
string ddocDir = null;
bool useDub = false;
bool noIgnoreFile = false;
bool dryRun = false;
bool force = false;

bool detectedGit;
bool detectedHg;

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
			"r|root",         "= VALUE Path to root of project directory. Default: Current directory", &rootPath,
			"module",         "= VALUE Override the module name. Default: packageVersion", &outModuleName,
			"ddoc",           "= VALUE Generate a DDOC macro file in the directory 'VALUE'.", &ddocDir,
			"no-ignore-file", "        Do not attempt to update .gitignore/.hgignore", &noIgnoreFile,
			"force",          "        Force overwriting the output file, even is it's up-to-date.", &force,
			"dry-run",        "        Dry run. Don't actually write or modify any files. Implies --trace",
				{ logLevel = LogLevel.trace; scriptlikeEcho = true; dryRun = true;},
			//"silent",         "        Silence all non-error output",           { logLevel = LogLevel.silent; },
			"q|quiet",        "        Quiet mode",                             { logLevel = LogLevel.quiet; },
			"v|verbose",      "        Verbose mode",                           { logLevel = LogLevel.verbose; },
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

	failEnforce(!outModuleName.canFind("."),
		"Module name cannot include '.'\n",
		"Instead of --module=", outModuleName, ", try using --module=",
		outModuleName.replace(".", "_"), "\n",
		usageHint);

	return true;
}

version(unittest) void main() {} else
void main(string[] args)
{
	// Handle args
	if(!doGetOpt(args))
		return;
	
	chdir(rootPath);
	
	try
		generatePackageVersion();
	catch(ErrorLevelException e)
		fail(e.msg);
		
	return;
}

void generatePackageVersion()
{
	import std.datetime;
	import std.path : buildPath, dirName;
	
	detectTools();
	
	// Grab basic info
	auto versionStr = getVersionStr();
	logTrace("versionStr: ", versionStr);
	
	auto now = Clock.currTime;
	auto nowStr = now.toString();
	auto nowISOStr = now.toISOExtString();
	
	// Generate dub extras
	string dubExtras;
	if(useDub)
		dubExtras = generateDubExtras(projectSourcePath);
	
	// Generate DDOC macros
	string ddocPath;
	if(ddocDir)
		ddocPath = generateDdocMacros(ddocDir, outPackageName, outModuleName, versionStr, nowStr, nowISOStr);
	
	// Generate D source code
	auto dModule =
`/++
Generated at `~nowStr~`
by gen-package-version `~packageVersion~`: 
$(LINK https://github.com/Abscissa/gen-package-version)
+/
module `~outPackageName~`.`~outModuleName~`;

/++
Version of this package.
+/
enum packageVersion = "`~versionStr~`";

/++
Human-readable timestamp of when this module was generated.
+/
enum packageTimestamp = "`~nowStr~`";

/++
Timestamp of when this module was generated, as an ISO Ext string.
Get a SysTime from this via:

------
std.datetime.fromISOExtString(packageTimestamp)
------
+/
enum packageTimestampISO = "`~nowISOStr~`";
`~dubExtras;
	//logTrace("--------------------------------------");
	//logTrace(dModule);
	//logTrace("--------------------------------------");
	
	// Determine output filepath
	auto packagePath = outPackageName.replace(".", dirSeparator);
	auto outPath = buildPath(projectSourcePath, packagePath, outModuleName) ~ ".d";
	logTrace("outPath: ", outPath);
	
	// Ensure directory for output file exits
	auto outDir = std.path.dirName(outPath);
	failEnforce(exists(Path(outDir)), "Output directory doesn't exist: ", outDir);
	failEnforce(isDir(Path(outDir)), "Output directory isn't a directory: ", outDir);

	// Update VCS ignore files
	if(!noIgnoreFile)
	{
		addToIgnoreFiles(outPath);

		if(ddocPath)
			addToIgnoreFiles(ddocPath);
	}

	// Check whether output file should be updated
	if(force)
		logVerbose(`--force used, skipping "up-to-date" check`);
	else
	{
		if(existsAsFile(outPath))
		{
			import std.regex;

			auto existingModule = cast(string) scriptlike.file.read(Path(outPath));
			auto adjustedExistingModule = existingModule
				.replaceFirst(regex(`Generated at [^\n]*\n`), `Generated at `~nowStr~"\n")
				.replaceFirst(regex(`packageTimestamp = "[^"]*";`), `packageTimestamp = "`~nowStr~`";`)
				.replaceFirst(regex(`packageTimestampISO = "[^"]*";`), `packageTimestampISO = "`~nowISOStr~`";`);

			if(adjustedExistingModule == dModule)
			{
				logVerbose("Existing version file is up-to-date, skipping overwrite: ", outPath);
				return;
			}
		}
	}
	
	// Write the file
	logVerbose("Saving to ", outPath);
	if(!dryRun)
	{
		try
			scriptlike.file.write(outPath, dModule);
		catch(FileException e)
			fail(e.msg);
	}
}

// Returns path to the output file that was (or would've been) written.
string generateDdocMacros(string outDir, string packageName, string moduleName,
	string ver, string timestamp, string timestampIso)
{
	import std.string : toUpper;
	auto macroPrefix = packageName.toUpper().replace(".", "_");
	
	// Ensure directory for output file exits
	failEnforce(exists(Path(outDir)), "DDOC output directory doesn't exist: ", outDir);
	failEnforce(isDir(Path(outDir)), "DDOC output directory isn't a directory: ", outDir);

	// Determine output filepath
	auto outPath = buildPath(outDir, moduleName) ~ ".ddoc";
	logTrace("ddoc outPath: ", outPath);
	
	// Generate DDOC macro code
	auto newDdoc =
`Ddoc

Macros:
`~macroPrefix~`_VERSION       = `~ver~`
`~macroPrefix~`_TIMESTAMP     = `~timestamp~`
`~macroPrefix~`_TIMESTAMP_ISO = `~timestampIso~`
`;
	
	// Check whether output file should be updated
	if(force)
		logVerbose(`--force used, skipping ddoc "up-to-date" check`);
	else
	{
		if(existsAsFile(outPath))
		{
			import std.regex;

			auto existingDdoc = cast(string) scriptlike.file.read(Path(outPath));
			auto adjustedExistingDdoc = existingDdoc
				.replaceFirst(regex(`_TIMESTAMP     = [^\n]*\n`), `_TIMESTAMP     = `~timestamp~"\n")
				.replaceFirst(regex(`_TIMESTAMP_ISO = [^\n]*\n`), `_TIMESTAMP_ISO = `~timestampIso~"\n");

			if(adjustedExistingDdoc == newDdoc)
			{
				logVerbose("Existing ddoc version macro file is up-to-date, skipping overwrite:", outPath);
				return outPath;
			}
		}
	}
	
	// Write the file
	logVerbose("Saving to ", outPath);
	if(!dryRun)
	{
		try
			scriptlike.file.write(outPath, newDdoc);
		catch(FileException e)
			fail(e.msg);
	}
	
	return outPath;
}

void detectTools()
{
	detectedGit = existsAsDir(".git");
	detectedHg = existsAsDir(".hg");
	
	logVerbose("Git working directory?: ", detectedGit);
	logVerbose("Hg working directory?: ", detectedHg);
}

// Obtain the version
string getVersionStr()
{
	string ver;

	// Try "git describe"
	ver = getVersionStrGit();

	// Try Mersurial
	if(ver.empty)
		ver = getVersionStrHg();
	
	// Try checking the name of the directory (ex, for packages fetched by dub)
	if(ver.empty)
		ver = getVersionStrInferFromDir();
	
	// Found nothing?
	if(ver.empty)
		ver = "unknown-ver";
	
	return ver;
}

// Attempt to get the version from git
string getVersionStrGit()
{
	import std.string : strip;

	// Don't bother running git if it's not even a git working directory
	if(!detectedGit)
		return null;
	
	auto result = tryRunCollect("git describe");
	if(!result.status)
		return result.output.strip();

	return null;
}

// Attempt to get the version from Mercurial
string getVersionStrHg()
{
	// Don't bother running hg if it's not even an hg working directory
	if(!detectedHg)
		return null;
	
	auto result = tryRunCollect(`hg log -r . --template '{latesttag}-{latesttagdistance}-{node|short}'`);
	if(!result.status)
	{
		auto parts = result.output.split("-");
		if(parts.length < 3) // Unexpected
			return null;
		
		// latesttagdistance == 0?
		if(parts[$-2] == "0")
			return parts[0..$-2].join("-"); // Return *only* the {latesttag} part
		else
			return result.output; // Return the whole thing
	}

	return null;
}

// Attempt to get the version by inferring from current directory name.
string getVersionStrInferFromDir()
{
	import std.string : chompPrefix, isNumeric;
	
	JSONValue jsonRoot;
	try
		jsonRoot = getPackageJsonInfo();
	catch(Exception e) // If "dub describe" failed
		return null;
	
	auto rootPackageName = jsonRoot["rootPackage"].str;
	auto currDir = getcwd().baseName().toString();
	logTrace("rootPackageName: ", rootPackageName);
	logTrace("currDir: ", currDir);
	
	auto prefix = rootPackageName ~ "-";
	if(currDir.startsWith(prefix))
	{
		auto versionPortion = currDir.chompPrefix(prefix);
		if(!versionPortion.empty)
		{
			if(isNumeric(versionPortion[0..1]))
				return "v"~versionPortion;
			else
				return versionPortion;
		}
	}
	
	return null;
}

// Obtains package info via "dub describe"
JSONValue getPackageJsonInfo()
{
	static isCached = false;
	static JSONValue jsonRoot;
	
	if(!isCached)
	{
		auto rawJson = runCollect("dub describe");
		jsonRoot = parseJSON( rawJson );
		isCached = true;
	}
	
	return jsonRoot;
}

// Auto-detects srcDir if srcDir doesn't already have a value.
// Returns D source code to be appended to the output file.
string generateDubExtras(ref string srcDir)
{
	auto jsonRoot = getPackageJsonInfo();
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
/++
DUB package name of this project.
Ie, dub.json's "name" field.
+/
enum packageName = "`~rootPackageName~`";

/++
Name of this project's target binary, minus extensions and prefixes.
Ie, dub.json's "targetName" field.

Note that depending on your needs, it may be better to
use std.file.thisExePath()
+/
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

void addToIgnoreFiles(string path)
{
	if(detectedGit)
		addToIgnore(".gitignore", path, false);

	if(detectedHg)
		addToIgnore(".hgignore", path, true);
}

void addToIgnore(string ignoreFileName, string path, bool useRegex)
{
	// Normalize to the standard git/hg ignore style.
	// Don't worry, this works on Windows just fine.
	path = path.replace("\\", "/");
	
	if(useRegex)
		path = "^" ~ path ~ "$";
	
	// Doesn't already exist? Create it.
	if(!exists(Path(ignoreFileName)))
	{
		logVerbose("No existing ", ignoreFileName, " file. Creating it.");
		if(!dryRun)
			scriptlike.file.write(ignoreFileName, path~"\n");

		return;
	}
	
	// Make sure it's actually a file
	if(!isFile(Path(ignoreFileName)))
	{
		logVerbose("Strange, ", ignoreFileName, " exists but isn't a file. Not updating it.");
		return; // Not a file? Don't even bother with it.
	}
	
	// Is 'path' already in the ignore file?
	import std.string : strip;
	auto isAlreadyInFile =
		File(ignoreFileName)
		.byLine()
		.map!(std.string.strip)()  // Get rid of any trailing \r byLine might have left us on Windows
		.map!(a => a.replace("\\", "/"))
		.canFind(path);
	
	// Append 'path' to the ignore file
	if(!isAlreadyInFile)
	{
		logVerbose("Pattern '", path, "' not found in ", ignoreFileName, " file. Adding it.");

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
		logVerbose("Pattern '", path, "' is already found in ", ignoreFileName, " file.");
}
