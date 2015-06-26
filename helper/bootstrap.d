import std.algorithm;
import std.exception;
import std.file;
import std.path;
import std.process;
import std.stdio;

immutable versionFile = "src/genPackageVersion/packageVersion.d";

immutable bootstrapVersionFileContent = 
q{module genPackageVersion.packageVersion;
enum packageVersion = "bootstrap";
};

int main(string[] args)
{
	enforce(args.length == 2,
		"Wrong number of args. Usage: (this_program) (path_to_scriptlike/)");
	
	// Create default version file
	if(!versionFile.exists)
		std.file.write(versionFile, bootstrapVersionFileContent);
	
	// Ensure trailing slash
	auto scriptlikePath = args[1];
	if(!scriptlikePath.endsWith(dirSeparator))
		scriptlikePath ~= dirSeparator;

	// Bootstrap
	return spawnShell(
		`rdmd -ofbin/bootstrap -Isrc -I`~scriptlikePath~`src `~
			`src/genPackageVersion/main.d genPackageVersion --src=src`
	).wait();
}
