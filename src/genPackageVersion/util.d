/// Misc utility module
module genPackageVersion.util;

import std.stdio;
import scriptlike.only;

string outPackageName = null;             /// Main cmd line argument to 'gen-package-version'
string outModuleName = "packageVersion";  /// --module=...
string projectSourcePath = null;          /// --src=...
string rootPath = ".";                    /// --root=...
string ddocDir = null;                    /// --ddoc=...
bool useDub = false;        /// --dub
bool noIgnoreFile = false;  /// --no-ignore-file
bool dryRun = false;        /// --dry-run
bool force = false;         /// --force

bool detectedGit;  /// After running detectTools(): Is this a git working directory?
bool detectedHg;   /// After running detectTools(): Is this a Mercurial working directory?

/// Populates the `detectedGit` and `detectedHg` bools.
void detectTools()
{
	detectedGit = existsAsDir(".git");
	detectedHg = existsAsDir(".hg");
	
	logVerbose("Git working directory?: ", detectedGit);
	logVerbose("Hg working directory?: ", detectedHg);
}

/// Logging level
enum LogLevel
{
	silent,
	quiet,
	normal,
	verbose,
	trace,
}
auto logLevel = LogLevel.normal; /// Current logging level

/// Log a message at a specific logging level
void logQuiet  (T...)(T args) { log!(LogLevel.quiet)(args); } ///ditto
void logNormal (T...)(T args) { log!(LogLevel.normal)(args); } ///ditto
void logVerbose(T...)(T args) { log!(LogLevel.verbose)(args); } ///ditto
void logTrace  (T...)(T args) { log!(LogLevel.trace)(args); } ///ditto
void log(LogLevel minimumLogLevel, T...)(T args) ///ditto
{
	static assert(minimumLogLevel != LogLevel.silent);
	
	if(logLevel >= minimumLogLevel)
		writeln(args);
}
