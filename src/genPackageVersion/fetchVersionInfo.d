/// Obtains package version string from various sources
module genPackageVersion.fetchVersionInfo;

import std.algorithm;
import std.array;
import std.json;

import scriptlike.only;

import genPackageVersion.fetchDubInfo;
import genPackageVersion.util;

/// Obtain the version
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

/// Attempt to get the version from git
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

/// Attempt to get the version from Mercurial
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

/// Attempt to get the version by inferring from current directory name.
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
