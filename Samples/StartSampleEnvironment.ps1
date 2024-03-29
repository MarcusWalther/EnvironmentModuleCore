# You can start an experimental shell with the following command line: powershell.exe -NoProfile -NoExit -File "<PathToStartSampleEnvironment.ps1>"
param(
    [string] $TempDirectory = "$(Join-Path $PSScriptRoot (Join-Path 'Env' 'Tmp'))",
    [string] $ConfigDirectory = "$(Join-Path $PSScriptRoot (Join-Path 'Env' 'Config'))",
    [string[]] $AdditionalModulePaths = @(),
    [switch] $IgnoreSamplesFolder
)

if($script:SetupPerformed) {
    return
}

$script:SetupPerformed = $true

# $global:VerbosePreference = "Continue"
$psModulePath  = ""
if(-not $ignoreSamplesFolder) {
    $psModulePath = "$PSScriptRoot"
}
if(($null -ne $AdditionalModulePaths) -and ($AdditionalModulePaths.Count -gt 0)) {
    if(-not $ignoreSamplesFolder) {
        $psModulePath += [IO.Path]::PathSeparator
    }
    $psModulePath += [System.String]::Join([IO.Path]::PathSeparator, $AdditionalModulePaths)
}
$env:PSModulePath = $psModulePath + [IO.Path]::PathSeparator + $env:PSModulePath

$env:ENVIRONMENT_MODULES_TMP = "$TempDirectory"
$env:ENVIRONMENT_MODULES_CONFIG = "$ConfigDirectory"

if($null -ne (Get-Module 'EnvironmentModuleCore')) {
    Remove-Module EnvironmentModuleCore -Force
}

# Remove the temp directory
Remove-Item -Recurse -Force "$(Join-Path $TempDirectory 'Modules')" -ErrorAction SilentlyContinue

$environmentModuleCorePath = "$(Resolve-Path (Join-Path $PSScriptRoot (Join-Path '..' 'EnvironmentModuleCore.psm1')))"
Import-Module "$environmentModuleCorePath"
Write-Host "Using EnvironmentModuleCore module $((Get-Module 'EnvironmentModuleCore')[0].ModuleBase) loaded from '$environmentModuleCorePath'"

$binaryAssembly = [System.Reflection.Assembly]::GetAssembly([EnvironmentModuleCore.ParameterInfo])
Write-Host "Libraries are loaded from $([System.IO.Path]::GetDirectoryName($binaryAssembly.Location))"
$versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($binaryAssembly.Location)
Write-Host "Library version is $($versionInfo.ProductVersion)"

Update-EnvironmentModuleCache
Clear-EnvironmentModuleSearchPaths -Force