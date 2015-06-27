/// Handles VCS ignore files.
module genPackageVersion.ignoreFiles;

import std.algorithm;
import std.array;
import std.stdio;
import std.string : strip;

import scriptlike.only;
import genPackageVersion.util;

/// Add `path` to ignore files for all VCSes detected.
/// Does nothing if `path` is already in the ignore file.
void addToIgnoreFiles(string path)
{
	if(detectedGit)
		addToIgnore(".gitignore", path, false);

	if(detectedHg)
		addToIgnore(".hgignore", path, true);
}

/// Add `path` to a VCS ignore file, unless it's already in the ignore file.
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
