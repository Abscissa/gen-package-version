gen-package-version
===================

Automatically generate a [D](http://dlang.org) module with version and timestamp information (detected from git) every time your program or library is built.

Even better, all your in-between builds will automatically have *their own* git-generated version number, including the git commit hash (for example: ```v1.2.0-1-g78f5cf9```). So there's never any confusion as to which "version" of v1.2.0 you're running!

[ [Changelog](https://github.com/Abscissa/gen-package-version/blob/master/CHANGELOG.md) ]

To Use:
-------

It's recommended to use [dub](http://code.dlang.org/getting_started) ([get dub here](http://code.dlang.org/download)). But if you wish, you can also forgo dub entirely (see the next section below).

First, add the following to your project's [dub.json](http://code.dlang.org/getting_started):

```json
{
	"dependencies": {
		"gen-package-version": "~>0.9.2"
	},
	"preGenerateCommands":
		["dub run gen-package-version -- your.package.name --src=path/to/src"]
}
```

Replace ```path/to/src``` with the path to your project's sources (most likely ```src``` or ```source```).

Replace ```your.package.name``` with the name of your project's D package (ex: ```std```, ```deimos```, ```coolsoft.coolproduct.component1```, etc...).

Optionally, you can replace ```--src=path/to/src``` with ```--dub```. Then, gen-package-version will use dub (via ```dub describe```) to automatically detect your source path and add some extra info in the packageVersion module it generates. More options are also available (see "Help Screen" below).

Finally, make sure your project is [tagged](https://git-scm.com/book/en/v2/Git-Basics-Tagging) with a version number (it must be a git "annotated" tag, ie a tag with a message - doesn't matter what the message is). Example:

```bash
$ git tag -a v1.2.0 -m 'This is version v1.2.0'
```

That's it. Now your program will always be able to access its own version number (auto-detected from git) and build timestamp:

```d
module your.package.name.main;

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

Every time you tag a new release (remember, annotated tag), your program will automatically know its new version number! Even builds from between releases will be easily distinguished.

If your project is a library, your *library's users* can also query the version of your lib:

```d
module myApp.main;

import std.stdio;
import myApp.packageVersion;
static import coolLib.packageVersion;

void main()
{
	writeln("My App ", packageVersion, "(@ ", packageTimestamp, ")");

	writeln("Using coolLib ", coolLib.packageVersion.packageVersion);
	writeln("  coolLib built @", coolLib.packageVersion.packageTimestamp);
}
```

By default, gen-package-version automatically adds the generated ```packageVersion.d``` file to your ```.gitignore``` (or creates it if you don't have one). This helps ensure the file's changes don't clutter your project's pull requests. If you'd rather gen-package-version left your ```.gitignore``` file alone, just include the ```--no-ignore-file``` flag.

Your project isn't built with dub?
----------------------------------

No prob! Just download and compile gen-package-version, then run it from your buildscript (or in your IDE's "Project Pre-Build Steps").

Download and compile using dub ([get dub](http://code.dlang.org/download)):
```bash
$ dub fetch gen-package-version
$ dub build gen-package-version

# Add this to your project's buildscript:
# dub run gen-package-version -- your.package.name --src=path/to/src
```

Or download and compile with no dub needed at all:
```bash
$ git clone https://github.com/Abscissa/gen-package-version.git
$ cd gen-package-version
$ git checkout v0.9.2  # Or newer

$ git clone https://github.com/Abscissa/scriptlike.git
$ cd scriptlike
$ git checkout v0.8.0  # Or newer
$ cd ..

$ rdmd --build-only -ofbin/gen-package-version -Isrc/ -Iscriptlike/src src/genPackageVersion/main.d

# Add this to your project's buildscript:
# [path/to/gen-package-version/]bin/gen-package-version your.package.name --src=path/to/src
```

Help Screen
-----------
View this help screen with ```dub run gen-package-version -- --help``` or ```gen-package-version --help```:

```
gen-package-version v0.9.2
<https://github.com/Abscissa/gen-package-version>
-------------------------------------------------
Generates a D module with version information automatically-detected
from git and (optionally) dub. This generated D file is automatically
added to .gitignore if necessary (unless using --no-ignore-file).

It is recommended to run this via DUB's preGenerateCommands by adding the
following lines to your project's dub.json:

    "dependencies": {
        "gen-package-version": "~>0.9.2"
    },
    "preGenerateCommands":
        ["cd $PACKAGE_DIR && dub run gen-package-version -- your.package.name --src=path/to/src"],

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
