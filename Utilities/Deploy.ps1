param(
    [string]
    $NuGetApiKey,
    [string]
    $Repository
)

pushd
cd (Join-Path $PSScriptRoot "..")

# Create the package directory
$packageFolder = (Join-Path "package" "EnvironmentModules")

if(Test-Path $packageFolder) {
    Remove-Item -Recurse -Force $packageFolder
}

mkdir $packageFolder

# Copy the relevant items to the package folder
cp "*.ps*1" $packageFolder
cp "*.dll" $packageFolder
cp "*.md" $packageFolder
cp "*.ps1xml" $packageFolder
cp "LICENSE*" $packageFolder
cp "Templates" $packageFolder -Recurse

# Publish the module
Publish-Module -Path $packageFolder -Repository $Repository -Verbose -NuGetApiKey $NuGetApiKey

# Cleanup
Remove-Item -Recurse -Force $packageFolder

popd