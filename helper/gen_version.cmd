@echo off
set gitver=unknown
for /f %%i in ('git describe') do set gitver=%%i
echo module genPackageVersion.packageVersion; > src\genPackageVersion\packageVersion.d
echo enum packageVersion = "%gitver%"; >> src\genPackageVersion\packageVersion.d
