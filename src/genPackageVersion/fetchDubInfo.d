/// Fetch package information from DUB.
module genPackageVersion.fetchDubInfo;

import std.algorithm;
import std.array;
import std.json;

import scriptlike.only;
import genPackageVersion.util;

/// Auto-detects srcDir if srcDir doesn't already have a value.
/// Returns D source code to be appended to the output file.
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

/// Obtains package info via "dub describe".
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

/// Get the JSON subtree for a specific package.
JSONValue getPackageInfo(JSONValue dubInfo, string packageName)
{
	auto packages = dubInfo["packages"].array;

	foreach(pack; packages)
	if(pack["name"].str)
		return pack;
	
	fail("Package '"~packageName~"' not found. Received bad data from 'dub describe'.");
	assert(0);
}
