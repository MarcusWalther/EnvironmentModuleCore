# Read the temp folder location
$moduleFileLocation = $MyInvocation.MyCommand.ScriptBlock.Module.Path
$env:ENVIRONMENT_MODULE_ROOT = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($moduleFileLocation, ".."))

# Include the util functions
. "${PSScriptRoot}\Utils.ps1"

$script:tmpEnvironmentRootPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($moduleFileLocation, "..", "Tmp"))

if($null -ne $env:ENVIRONMENT_MODULES_TMP) {
    $script:tmpEnvironmentRootPath = $env:ENVIRONMENT_MODULES_TMP
}
else {
    $env:ENVIRONMENT_MODULES_TMP = $script:tmpEnvironmentRootPath
}

# Configure the tmp directory and append it to the PSModulePath
Write-Verbose "Using environment module temp path $($script:tmpEnvironmentRootPath)"
$script:tmpEnvironmentModulePath = ([System.IO.Path]::Combine($script:tmpEnvironmentRootPath, "Modules"))

mkdir $script:tmpEnvironmentRootPath -Force
mkdir $script:tmpEnvironmentModulePath -Force

if(-not (Test-PathPartOfEnvironmentVariable $script:tmpEnvironmentModulePath "PSModulePath")) {
    $env:PSModulePath = "$env:PSModulePath;$script:tmpEnvironmentModulePath"
}

# Read the config folder location
$script:configEnvironmentRootPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($moduleFileLocation, "..", "Config"))

if($null -ne $env:ENVIRONMENT_MODULES_CONFIG) {
    $script:configEnvironmentRootPath = $env:ENVIRONMENT_MODULES_CONFIG
}
else {
    $env:ENVIRONMENT_MODULES_CONFIG = $script:configEnvironmentRootPath
}

mkdir $script:configEnvironmentRootPath -Force

# Setup the variables
$script:loadedEnvironmentModules = @{} # ShortName -> ModuleInfo
$script:loadedEnvironmentModuleAliases = @{} # AliasName -> EnvironmentModuleAliasInfo[]
$script:loadedEnvironmentModuleFunctions = @{} # FunctionName -> EnvironmentModuleFunctionInfo[]

$script:environmentModules = @{} # FullName -> ModuleInfoBase
$script:customSearchPaths = New-Object "System.Collections.Generic.Dictionary[String, System.Collections.Generic.List[EnvironmentModules.SearchPath]]"
$script:silentUnload = $false

# Include the file handling functions
. "${PSScriptRoot}\DescriptionFile.ps1"

# Initialize the cache file to speed up the module
. "${PSScriptRoot}\Storage.ps1"
if(test-path $script:moduleCacheFileLocation)
{
    Initialize-EnvironmentModuleCache
}
else
{
    Update-EnvironmentModuleCache
}

# Initialize the custom search path handling
if(test-path $script:searchPathsFileLocation)
{
    Initialize-CustomSearchPaths
}

# Include the dismounting features
. "${PSScriptRoot}\Dismounting.ps1"

# Include the mounting features
. "${PSScriptRoot}\Mounting.ps1"

# Include the create and edit functions for environment modules
. "${PSScriptRoot}\ModuleCreation.ps1"

# Include the main code
. "${PSScriptRoot}\EnvironmentModules.ps1"