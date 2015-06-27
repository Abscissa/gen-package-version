module genPackageVersion.main;

import genPackageVersion.genAll;

version(unittest) void main() {} else
void main(string[] args)
{
	genPackageVersionMain(args);
}
