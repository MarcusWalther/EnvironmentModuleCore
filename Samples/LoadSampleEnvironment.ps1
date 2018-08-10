Import-Module "EnvironmentModules"

$env:PSModulePath = "{0:s};{1:s}" -f $env:PSModulePath, (Join-Path $PSScriptRoot "..\")
Update-EnvironmentModuleCache