gen-package-version - ChangeLog
===============================

(Dates below are YYYY/MM/DD)

v1.0.3 - 2015/08/17
-------------------
- **Fixed:** Compile error for unittest builds.

v1.0.2 - 2015/07/01
-------------------
- **Enhancement:** Now works on DMD 2.066.1 (previously required 2.067.0 or up).

v1.0.1 - 2015/06/28
-------------------
- **Fixed:** Don't use a broken scriptlike release (v0.9.0), use v0.9.1 instead.

v1.0.0 - 2015/06/27
-------------------
- **Change:** The generated ```packageTimestamp``` is changed from [ISOExt](http://dlang.org/phobos/std_datetime.html#toISOExtString) format to human readable. The ISOExt formatted version is now called ```packageTimestampISO```.
- **Change:** Value for ```--module``` is no longer allowed to contain periods.
- **Enhancement:** Basic ability to be used as a library. See the [README](https://github.com/Abscissa/gen-package-version/blob/master/README.md) for details.
- **Enhancement:** Add ```-r|--root``` to support projects in any directory, not just the current directory.
- **Enhancement:** Minor improvements to ```--verbose``` and ```--trace``` outputs.
- **Fixed:** Don't update the version file (and thus trigger a project rebuild) if the version file doesn't need updated. Bypass this check with the new ```--force``` flag.
- **Fixed:** Don't rebuild gen-package-version if not needed.
- **Fixed:** Failure on Windows when target project is on a different drive letter from current working directory.

v0.9.4 - 2015/06/16
-------------------
- **Enhancement:** Support detecting the version number via Mercurial (hg).
- **Enhancement:** Support .hgignore for Mercurial working directories.

v0.9.3 - 2015/06/15
-------------------
- **Enhancement:** If detecting the version number via git fails, attempt to detect it via the current directory name (ex, ```~/.dub/packages/[project-name]-[version-tag]```).
- **Enhancement:** Don't bother running git if there's no ```.git``` directory.
- **Enhancement:** Bootstraps itself, so gen-package-version itself enjoys the following fix:
- **Fixed:** Fails to detect version number for packages fetched by dub (since they lack ```.git```).

v0.9.2 - 2015/06/14
-------------------
- **Fixed:** The old recommended "preGenerateCommands" led to problems (project dependencies that use gen-package-version would run it from the wrong directory).

v0.9.1 - 2015/06/14
-------------------
- **Fixed:** ```helper/gen_version.sh``` isn't set as executable when checked out through dub.

v0.9.0 - 2015/06/14
-------------------
- **New:** Initial release.
