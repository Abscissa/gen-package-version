#!/bin/sh
gitver=$(git describe) || gitver=unknown
echo "module genPackageVersion.packageVersion;" > src/genPackageVersion/packageVersion.d
echo "enum packageVersion = \"$gitver\";" >> src/genPackageVersion/packageVersion.d
