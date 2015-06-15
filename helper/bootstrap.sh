#!/bin/sh
echo "module genPackageVersion.packageVersion;" > src/genPackageVersion/packageVersion.d
echo "enum packageVersion = \"bootstrap\";" >> src/genPackageVersion/packageVersion.d
rdmd -ofbin/bootstrap -Isrc -I$1src src/genPackageVersion/main.d genPackageVersion --src=src
