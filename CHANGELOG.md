gen-package-version - ChangeLog
===============================

(Dates below are YYYY/MM/DD)

v0.9.5 - TBD
-------------------
- **Enhancement:** Add ```--ddoc=dir``` to also generate a DDOC macro file.
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
- **Enhancement:** If detecting the version number via git fails, attempt to detect it via the currect directory name (ex, ```~/.dub/packages/[project-name]-[version-tag]```).
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
