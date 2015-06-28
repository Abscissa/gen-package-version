/// Main entry point for gen-package-version
module genPackageVersion.genAll;

import std.algorithm;
import std.array;
import std.getopt;
import std.stdio;

import scriptlike.only;

import genPackageVersion.fetchDubInfo;
import genPackageVersion.fetchVersionInfo;
import genPackageVersion.genDdocMacros;
import genPackageVersion.genDModule;
import genPackageVersion.ignoreFiles;
import genPackageVersion.util;

static import genPackageVersionInfo = genPackageVersion.packageVersion;

/// The --help message
immutable helpBanner = (
`gen-package-version `~genPackageVersionInfo.packageVersion~`
<https://github.com/Abscissa/gen-package-version>
-------------------------------------------------
Generates a D module with version information automatically-detected
from git or hg and (optionally) dub. This generated D file is automatically
added to .gitignore/.hgignore if necessary (unless using --no-ignore-file).

It is recommended to run this via DUB's preGenerateCommands by copy/pasting the
following lines into your project's dub.json:

	"dependencies": {
		"gen-package-version": "~>1.0.0"
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

/// Main entry point for genPackageVersion
void genPackageVersionMain(string[] args)
{
	// Handle args
	if(!doGetOpt(args))
		return;
	
	try
		generateAll();
	catch(ErrorLevelException e)
		fail(e.msg);
		
	return;
}

/// Returns: Should program execution continue?
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
		writeln(genPackageVersionInfo.packageVersion);
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

/// After cmdline args have been processed, this does all the main work.
void generateAll()
{
	import std.datetime;
	
	auto originalWorkingDir = getcwd();
	scope(exit) chdir(originalWorkingDir);
	chdir(rootPath);

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
	
	// Generate D module
	auto dModulePath = generateDModule(outPackageName, outModuleName, versionStr, nowStr, nowISOStr, dubExtras);

	// Generate DDOC macros
	string ddocPath;
	if(ddocDir)
		ddocPath = generateDdocMacros(ddocDir, outPackageName, outModuleName, versionStr, nowStr, nowISOStr);

	// Update VCS ignore files
	if(!noIgnoreFile)
	{
		addToIgnoreFiles(dModulePath);

		if(ddocPath)
			addToIgnoreFiles(ddocPath);
	}
}
