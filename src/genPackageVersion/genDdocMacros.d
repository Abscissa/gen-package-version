/// Generates a DDOC macros file for package version info.
module genPackageVersion.genDdocMacros;

import std.array;
import std.string : toUpper;

import scriptlike.only;
import genPackageVersion.util;

/// Returns path to the output file that was (or would've been) written.
string generateDdocMacros(string outDir, string packageName, string moduleName,
	string ver, string timestamp, string timestampIso)
{
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
	
	import scriptlike.file : scriptlikeRead = read, scriptlikeWrite = write;

	// Check whether output file should be updated
	if(force)
		logVerbose(`--force used, skipping ddoc "up-to-date" check`);
	else
	{
		if(existsAsFile(outPath))
		{
			import std.regex;

			auto existingDdoc = cast(string) scriptlikeRead(Path(outPath));
			auto adjustedExistingDdoc = existingDdoc
				.replaceFirst(regex(`_TIMESTAMP     = [^\n]*\n`), `_TIMESTAMP     = `~timestamp~"\n")
				.replaceFirst(regex(`_TIMESTAMP_ISO = [^\n]*\n`), `_TIMESTAMP_ISO = `~timestampIso~"\n");

			if(adjustedExistingDdoc == newDdoc)
			{
				logVerbose("Existing ddoc version macro file is up-to-date, skipping overwrite of ", outPath);
				return outPath;
			}
		}
	}
	
	// Write the file
	logVerbose("Saving to ", outPath);
	if(!dryRun)
	{
		try
			scriptlikeWrite(outPath, newDdoc);
		catch(FileException e)
			fail(e.msg);
	}
	
	return outPath;
}
