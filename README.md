gen-package-version
===================

Generate a [D](http://dlang.org) module with version and timestamp information automatically-detected from git.

[ [Changelog](https://github.com/Abscissa/gen-package-version/blob/master/CHANGELOG.md) ]

To Use:
-------

Insert the following in your project's [dub.json](http://code.dlang.org/getting_started):

```json
{
	...
	"dependencies": {
		...
		"gen-package-version": "~>0.9.0",
	},
	"preGenerateCommands":
		["dub run gen-package-version -- your.package.name --src=path/to/src"],
```

...replacing ```path/to/src``` with wherever your project's sources are (most likely ```src``` or ```source```), and  ```your.package.name``` with whatever the main D package of your project is named (ex: "std", "deimos", "coolsoft.coolproduct.component1", etc...).

Optionally, you can replace ```--src=path/to/src``` with ```--dub``` and gen-package-version will use dub (via ```dub describe```) to automatically detect your source path and add some extra info in the packageVersion module it generates. More optiona are available (see "Help Screen" section below).

Then, make sure your project is [tagged](https://git-scm.com/book/en/v2/Git-Basics-Taggingsrc=path/to/src) with a version number (it must be a git "annotated" tag, ie a tag with a message, doesn't matter what the message is). Ex:

```bash
$ git tag -a v1.2.0 -m 'This is version v1.2.0'
```

That's it. Now your program will always be able to access it's own version number (auto-detected from git) and build timestamp:

```d
module your.package.name;

import std.stdio;
import your.package.name.packageVersion;

void main()
{
	writeln("My Cool Program ", packageVersion);
	writeln("Built on ", packageTimestamp);
	
	// Only works of you used "--dub"
	//writeln(`The "name" field in my dub.json is: `, packageName);
}
```

By default, gen-package-version automatically adds the generated "packageVersion.d" file to your .gitignore (or creates .gitignore if there isn't one). This helps ensure the file's changes don't clutter your project's pull requests. If you'd rather gen-package-version left your .gitignore file alone, just include the ```--no-ignore-file``` flag.

Help Screen
-----------
View this help screen with ```dub run gen-package-version -- --help``` or ```gen-package-version --help```:

```
gen-package-version v0.9.0
<https://github.com/Abscissa/gen-package-version>
-------------------------------------------------
Generates a D module with version information automatically-detected
from git and (optionally) dub. This generated D file is automatically
added to .gitignore if necessary (unless using --no-ignore-file).

It is recommended to run this via DUB's preGenerateCommands by adding the
following lines to your project's dub.json:

    "dependencies": {
        "gen-package-version": "~>0.9.0"
    },
    "preGenerateCommands":
        ["dub run gen-package-version -- your.package.name --src=path/to/src"],

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

gen-package-version foo.bar --dub
    Generates module "foo.bar.packageVersion" in the file:
        (your_src_dir)/foo/bar/packageVersion.d

    Where (your_src_dir) above is auto-detected via "dub describe".
    The first path in "importPaths" is assumed to be (your_src_dir).
    
    Additional info is available when using --dub:

    writeln("This program's name is ", packageName);

OPTIONS:
              --dub         Use dub. May be slightly slower, but allows --src to be auto-detected, and adds extra info to the generated module.
-s            --src = VALUE Path to source files. Required unless --dub is used.
           --module = VALUE Override the module name. Default: packageVersion
   --no-ignore-file         Do not attempt to update .gitignore
          --dry-run         Dry run. Don't actually write or modify any files. Implies --verbose
-q          --quiet         Quiet mode
-v        --verbose         Verbose mode
            --trace         Extremely verbose mode (for debugging)
          --version         Show this program's version number and exit
-h           --help This help information.
```
