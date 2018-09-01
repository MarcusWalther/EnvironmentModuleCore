$global:VerbosePreference = "Continue"
$env:PSModulePath = "$PSScriptRoot;$(Resolve-Path (Join-Path $PSScriptRoot '..\Tmp\Modules'));$(Resolve-Path (Join-Path $PSScriptRoot '..\Test'))"
#$env:PSModulePath = "$env:PSModulePath;$(Resolve-Path (Join-Path $PSScriptRoot '..\..\'))"
Update-EnvironmentModuleCache
Clear-CustomSearchPaths -Force