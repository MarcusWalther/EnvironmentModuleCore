# You can start an experimental shell with the following command line: powershell.exe -NoProfile -NoExit -File "<PathToStartSampleEnvironment.ps1>"
param(
    [string] $TempDirectory = "$(Join-Path $PSScriptRoot 'Env\Tmp')",
    [string] $ConfigDirectory = "$(Join-Path $PSScriptRoot 'Env\Config')",
    [string[]] $AdditionalModulePaths = @()
)


$global:VerbosePreference = "Continue"
$env:PSModulePath = "$PSScriptRoot;" + [System.String]::Join(";", $AdditionalModulePaths)
$env:ENVIRONMENT_MODULES_TMP = "$TempDirectory"
$env:ENVIRONMENT_MODULES_CONFIG = "$ConfigDirectory"

if($null -ne (Get-Module 'EnvironmentModules')) {
    Remove-Module EnvironmentModules
}

# Remove the temp directory
Remove-Item -Recurse -Force "$(Join-Path $PSScriptRoot 'Env\Tmp\Modules')" -ErrorAction SilentlyContinue

Import-Module "$(Resolve-Path (Join-Path $PSScriptRoot '..\EnvironmentModules.psm1'))"

Update-EnvironmentModuleCache
Clear-EnvironmentModuleSearchPaths -Force