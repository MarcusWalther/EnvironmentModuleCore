<#
This script will download the latest libraries from Nuget that are required to use the module.
#>

Push-Location
Set-Location (Join-Path $PSScriptRoot "..")

# Create the nuget directory
$nugetDirectory = "Nuget"

New-Item -ItemType directory -Force $nugetDirectory
Set-Location $nugetDirectory

nuget install EnvironmentModuleCore

$libraries = (Get-ChildItem "." "lib" -Recurse) | ForEach-Object {Get-ChildItem $_ (Join-Path "netstandard2.0" "*.dll")} | Select-Object -ExpandProperty "Fullname"
foreach($library in $libraries) {
    Copy-Item $library ".."
    Write-Verbose "Found library $library"
}

Pop-Location