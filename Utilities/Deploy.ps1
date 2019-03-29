param(
    [string]
    $NuGetApiKey,
    [string]
    $Repository
)

Push-Location
Set-Location(Join-Path $PSScriptRoot "..")

# Create the package directory
$packageFolder = (Join-Path "package" "EnvironmentModules")

if(Test-Path $packageFolder) {
    Remove-Item -Recurse -Force $packageFolder
}

mkdir $packageFolder

# Copy the relevant items to the package folder
Copy-Item "*.ps*1" $packageFolder
Copy-Item "*.dll" $packageFolder
Copy-Item "*.md" $packageFolder
Copy-Item "*.ps1xml" $packageFolder
Copy-Item "LICENSE*" $packageFolder
Copy-Item "Icon.png" $packageFolder
Copy-Item "Templates" $packageFolder -Recurse

# Publish the module
Publish-Module -Path $packageFolder -Repository $Repository -Verbose -NuGetApiKey $NuGetApiKey

# Cleanup
Remove-Item -Recurse -Force $packageFolder

Pop-Location