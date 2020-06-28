# Read the temp folder location
$script:moduleFileLocation = $MyInvocation.MyCommand.ScriptBlock.Module.Path
$env:ENVIRONMENT_MODULE_ROOT = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:moduleFileLocation, ".."))
$localStorageFileLocation = "$env:LOCALAPPDATA"
if(-not $localStorageFileLocation) {
    $localStorageFileLocation = Join-Path (Resolve-Path "~") ".config/powershell/EnvironmentModuleCore"
}
else {
    $localStorageFileLocation += "/PowerShell/EnvironmentModuleCore"
}

$globalStorageFileLocation = "$env:PROGRAMDATA"
if(-not $globalStorageFileLocation) {
    $globalStorageFileLocation = Join-Path (Resolve-Path "~") ".powershell/EnvironmentModuleCore"
}
else {
    $globalStorageFileLocation += "/PowerShell/EnvironmentModuleCore"
}

# Include the util functions
. (Join-Path $PSScriptRoot "Utils.ps1")

if($null -ne $env:ENVIRONMENT_MODULES_TMP) {
    $script:tmpEnvironmentRootPath = $env:ENVIRONMENT_MODULES_TMP
}
else {
    $script:tmpEnvironmentRootPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($localStorageFileLocation, "Tmp"))
    $env:ENVIRONMENT_MODULES_TMP = $script:tmpEnvironmentRootPath
}

$script:tmpEnvironmentRootSessionPath = (Join-Path $script:tmpEnvironmentRootPath "Environment_$PID")
New-Item -ItemType directory $script:tmpEnvironmentRootPath -Force
foreach($directory in (Get-ChildItem (Join-Path $script:tmpEnvironmentRootPath "Environment_*"))) {
    if($directory.Name -Match "Environment_(?<PID>[0-9]+)") {
        $processInfo = (Get-Process -Id $Matches["PID"] -ErrorAction SilentlyContinue)
        if($null -eq $processInfo) {
            Remove-Item -Recurse -Force $directory
        }
    }
}

New-Item -ItemType directory $script:tmpEnvironmentRootSessionPath -Force

# Configure the tmp directory and append it to the PSModulePath
Write-Verbose "Using environment module temp path $($script:tmpEnvironmentRootPath)"
$script:tmpEnvironmentModulePath = ([System.IO.Path]::Combine($script:tmpEnvironmentRootPath, "Modules"))

New-Item -ItemType directory $script:tmpEnvironmentModulePath -Force

if(-not (Test-PathPartOfEnvironmentVariable $script:tmpEnvironmentModulePath "PSModulePath")) {
    $env:PSModulePath = "$($env:PSModulePath)$([IO.Path]::PathSeparator)$($script:tmpEnvironmentModulePath)"
}

# Read the config folder locations
$script:localConfigEnvironmentRootPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($localStorageFileLocation, "Config"))
$script:globalConfigEnvironmentRootPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($globalStorageFileLocation, "Config"))

if($null -ne $env:ENVIRONMENT_MODULES_CONFIG) {
    $script:localConfigEnvironmentRootPath = $env:ENVIRONMENT_MODULES_CONFIG
}
else {
    $env:ENVIRONMENT_MODULES_CONFIG = $script:localConfigEnvironmentRootPath
}

New-Item -ItemType directory $script:localConfigEnvironmentRootPath -Force

try {
    New-Item -ItemType directory $script:globalConfigEnvironmentRootPath -Force
}
catch {
    Write-Verbose "No write access to global configuration"
}

# Setup the variables
$script:configuration = @{} # Configuration parameters
$script:loadedEnvironmentModules = @{} # ShortName -> ModuleInfo
$script:loadedEnvironmentModuleAliases = @{} # AliasName -> AliasInfo[]
$script:loadedEnvironmentModuleFunctions = @{} # FunctionName -> FunctionInfo[]
$script:loadedEnvironmentModuleSetPaths = @{} # FullName -> Dictionary[string, string]
$script:environmentModuleParameters = @{} # ParameterName -> ParameterInfo

$script:environmentModules = @{} # FullName -> ModuleInfoBase
$script:customSearchPaths = New-Object "System.Collections.Generic.Dictionary[String, System.Collections.Generic.List[EnvironmentModuleCore.SearchPath]]"
$script:silentUnload = $false # Indicates if output should be printed on module unload
$script:silentLoad = $false # Indicates if output should be printed on module load

# Initialialize the configuration
. (Join-Path $PSScriptRoot "Configuration.ps1")
$script:configurationFilePath = (Join-Path $script:localConfigEnvironmentRootPath "Configuration.xml")
Import-EnvironmentModuleCoreConfiguration $script:configurationFilePath

# Include the module parameter functions
. (Join-Path $PSScriptRoot "ModuleParameters.ps1")

# Include the file handling functions
. (Join-Path $PSScriptRoot "DescriptionFile.ps1")

# Initialize the cache file to speed up the module
. (Join-Path $PSScriptRoot "Storage.ps1")
if(test-path $script:moduleCacheFileLocation)
{
    Initialize-EnvironmentModuleCache
}
else
{
    Update-EnvironmentModuleCache
}

# Initialize the custom search path handling
if(test-path $script:localSearchPathsFileLocation)
{
    Initialize-CustomSearchPaths
}

# Include the dismounting features
. (Join-Path $PSScriptRoot "Dismounting.ps1")

# Include the mounting features
. (Join-Path $PSScriptRoot "Mounting.ps1")

# Include the create and edit functions for environment modules
. (Join-Path $PSScriptRoot "ModuleCreation.ps1")

# Include the main code
. (Join-Path $PSScriptRoot "EnvironmentModuleCore.ps1")

# Load the extensions
if(Test-Path (Join-Path $PSScriptRoot "Extensions")) {
    foreach($file in Get-ChildItem (Join-Path $PSScriptRoot (Join-Path "Extensions" "*.ps1"))) {
        Write-Verbose "Loading Extension $file"
        . $file
    }
}
