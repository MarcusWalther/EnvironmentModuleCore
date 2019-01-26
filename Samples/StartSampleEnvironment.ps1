# You can start an experimental shell with the following command line: powershell.exe -NoProfile -NoExit -File "<PathToStartSampleEnvironment.ps1>"
param(
    [string] $TempDirectory = "$(Join-Path $PSScriptRoot (Join-Path 'Env' 'Tmp'))",
    [string] $ConfigDirectory = "$(Join-Path $PSScriptRoot (Join-Path 'Env' 'Config'))",
    [string[]] $AdditionalModulePaths = @(),
    [switch] $IgnoreSamplesFolder
)

# $global:VerbosePreference = "Continue"
$env:PSModulePath  = ""
if(-not $ignoreSamplesFolder) {
    $env:PSModulePath = "$PSScriptRoot"
}
if(($null -ne $AdditionalModulePaths) -and ($AdditionalModulePaths.Count -gt 0)) {
    if(-not $ignoreSamplesFolder) {
        $env:PSModulePath += [IO.Path]::PathSeparator
    }
    $env:PSModulePath += [System.String]::Join([IO.Path]::PathSeparator, $AdditionalModulePaths)
}
$env:ENVIRONMENT_MODULES_TMP = "$TempDirectory"
$env:ENVIRONMENT_MODULES_CONFIG = "$ConfigDirectory"

if($null -ne (Get-Module 'EnvironmentModules')) {
    Remove-Module EnvironmentModules
}

# Remove the temp directory
Remove-Item -Recurse -Force "$(Join-Path $TempDirectory 'Modules')" -ErrorAction SilentlyContinue

Import-Module "$(Resolve-Path (Join-Path $PSScriptRoot (Join-Path '..' 'EnvironmentModules.psm1')))"

Update-EnvironmentModuleCache
Clear-EnvironmentModuleSearchPaths -Force