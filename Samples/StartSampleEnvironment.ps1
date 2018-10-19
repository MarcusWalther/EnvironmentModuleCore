# You can start an experimental shell with the following command line: powershell.exe -NoProfile -NoExit -File "<PathToStartSampleEnvironment.ps1>"

$global:VerbosePreference = "Continue"
$env:PSModulePath = "$PSScriptRoot;$(Resolve-Path (Join-Path $PSScriptRoot '..\Tmp\Modules'))"
$env:ENVIRONMENT_MODULES_TMP = "$(Join-Path $PSScriptRoot 'Env\Tmp')"
$env:ENVIRONMENT_MODULES_CONFIG = "$(Join-Path $PSScriptRoot 'Env\Config')"

if($null -ne (Get-Module 'EnvironmentModules')) {
    Remove-Module EnvironmentModules
}
Import-Module "$(Resolve-Path (Join-Path $PSScriptRoot '..\EnvironmentModules.psm1'))"

Update-EnvironmentModuleCache
Clear-EnvironmentModuleSearchPaths -Force