/// Generates a D module for package version info.
module genPackageVersion.genDModule;

import std.array;
import scriptlike.only;

import genPackageVersion.util;
import genPackageVersion.packageVersion;

/// Returns path to the output file that was (or would've been) written.
string generateDModule(string packageName, string moduleName,
	string ver, string timestamp, string timestampIso, string dubExtras)
{
	// Generate D source code
	auto dModule =
`/++
Generated at `~timestamp~`
by gen-package-version `~packageVersion~`: 
$(LINK https://github.com/Abscissa/gen-package-version)
+/
module `~outPackageName~`.`~outModuleName~`;

/++
Version of this package.
+/
enum packageVersion = "`~ver~`";

/++
Human-readable timestamp of when this module was generated.
+/
enum packageTimestamp = "`~timestamp~`";

/++
Timestamp of when this module was generated, as an ISO Ext string.
Get a SysTime from this via:

------
std.datetime.fromISOExtString(packageTimestampISO)
------
+/
enum packageTimestampISO = "`~timestampIso~`";
`~dubExtras;
	//logTrace("--------------------------------------");
	//logTrace(dModule);
	//logTrace("--------------------------------------");
	
	import std.path : stdBuildPath = buildPath, stdDirName = dirName, dirSeparator;
	import scriptlike.file : scriptlikeRead = read, scriptlikeWrite = write;
	
	// Determine output filepath
	auto packagePath = outPackageName.replace(".", dirSeparator);
	auto outPath = stdBuildPath(projectSourcePath, packagePath, outModuleName) ~ ".d";
	logTrace("outPath: ", outPath);
	
	// Ensure directory for output file exits
	auto outDir = stdDirName(outPath);
	failEnforce(exists(Path(outDir)), "Output directory doesn't exist: ", outDir);
	failEnforce(isDir(Path(outDir)), "Output directory isn't a directory: ", outDir);
	
	// Check whether output file should be updated
	if(force)
		logVerbose(`--force used, skipping "up-to-date" check`);
	else
	{
		if(existsAsFile(outPath))
		{
			import std.regex;

			auto existingModule = cast(string) scriptlikeRead(Path(outPath));
			auto adjustedExistingModule = existingModule
				.replaceFirst(regex(`Generated at [^\n]*\n`), `Generated at `~timestamp~"\n")
				.replaceFirst(regex(`packageTimestamp = "[^"]*";`), `packageTimestamp = "`~timestamp~`";`)
				.replaceFirst(regex(`packageTimestampISO = "[^"]*";`), `packageTimestampISO = "`~timestampIso~`";`);

			if(adjustedExistingModule == dModule)
			{
				logVerbose("Existing version file is up-to-date, skipping overwrite of ", outPath);
				return outPath;
			}
		}
	}
	
	// Write the file
	logVerbose("Saving to ", outPath);
	if(!dryRun)
	{
		try
			scriptlikeWrite(outPath, dModule);
		catch(FileException e)
			fail(e.msg);
	}
	
	return outPath;
}
