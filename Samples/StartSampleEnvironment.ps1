# You can start an experimental shell with the following command line: powershell.exe -NoProfile -NoExit -File "<PathToStartSampleEnvironment.ps1>"

$global:VerbosePreference = "Continue"
$env:PSModulePath = "$PSScriptRoot;$(Resolve-Path (Join-Path $PSScriptRoot '..\Tmp\Modules'));$(Resolve-Path (Join-Path $PSScriptRoot '..\Test'))"
#$env:PSModulePath = "$env:PSModulePath;$(Resolve-Path (Join-Path $PSScriptRoot '..\..\'))"
Update-EnvironmentModuleCache
Clear-EnvironmentModuleSearchPaths -Force