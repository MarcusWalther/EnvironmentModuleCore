<#
.SYNOPSIS
    Pack and upload the module to the NuGet server.
.DESCRIPTION
    This script will copy all required files to the package folder, so that it can be uploaded cleanly to the Nuget server.
.Parameter NuGetApiKey
    The API key that should be used for the upload.
.Parameter Repository
    The repository that should be used as target.
#>
param(
    [string]
    $NuGetApiKey,
    [string]
    $Repository
)

Push-Location
Set-Location(Join-Path $PSScriptRoot "..")

# Create the package directory
$packageFolder = (Join-Path "package" "EnvironmentModuleCore")

if(Test-Path $packageFolder) {
    Remove-Item -Recurse -Force $packageFolder
}

New-Item -ItemType directory $packageFolder

# Copy the relevant items to the package folder
Copy-Item "*.ps*1" $packageFolder
Copy-Item "*.dll" $packageFolder
Copy-Item "LICENSE.md" $packageFolder
Copy-Item "*.ps1xml" $packageFolder
Copy-Item "LICENSE*" $packageFolder
Copy-Item "Templates" $packageFolder -Recurse
Copy-Item "Extensions" $packageFolder -Recurse

# Publish the module
Publish-Module -Path $packageFolder -Repository $Repository -Verbose -NuGetApiKey $NuGetApiKey

# Cleanup
Remove-Item -Recurse -Force $packageFolder

Pop-Location