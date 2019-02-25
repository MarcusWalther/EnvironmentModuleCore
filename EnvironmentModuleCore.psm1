# Read the temp folder location
$script:moduleFileLocation = $MyInvocation.MyCommand.ScriptBlock.Module.Path
$env:ENVIRONMENT_MODULE_ROOT = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:moduleFileLocation, ".."))
$storageFileLocation = "$env:APPDATA\PowerShell\EnvironmentModules"

# Include the util functions
. (Join-Path $PSScriptRoot "Utils.ps1")

if($null -ne $env:ENVIRONMENT_MODULES_TMP) {
    $script:tmpEnvironmentRootPath = $env:ENVIRONMENT_MODULES_TMP
}
else {
    $script:tmpEnvironmentRootPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($storageFileLocation, "Tmp"))
    $env:ENVIRONMENT_MODULES_TMP = $script:tmpEnvironmentRootPath
}

$script:tmpEnvironmentRootSessionPath = (Join-Path $script:tmpEnvironmentRootPath "Environment_$PID")
mkdir $script:tmpEnvironmentRootPath -Force
foreach($directory in (Get-ChildItem (Join-Path $script:tmpEnvironmentRootPath "Environment_*"))) {
    if($directory.Name -Match "Environment_(?<PID>[0-9]+)") {
        $processInfo = (Get-Process -Id $Matches["PID"] -ErrorAction SilentlyContinue)
        if($null -eq $processInfo) {
            Remove-Item -Recurse -Force $directory
        }
    }
}

mkdir $script:tmpEnvironmentRootSessionPath -Force

# Configure the tmp directory and append it to the PSModulePath
Write-Verbose "Using environment module temp path $($script:tmpEnvironmentRootPath)"
$script:tmpEnvironmentModulePath = ([System.IO.Path]::Combine($script:tmpEnvironmentRootPath, "Modules"))

mkdir $script:tmpEnvironmentModulePath -Force

if(-not (Test-PathPartOfEnvironmentVariable $script:tmpEnvironmentModulePath "PSModulePath")) {
    $env:PSModulePath = "$($env:PSModulePath)$([IO.Path]::PathSeparator)$($script:tmpEnvironmentModulePath)"
}

# Read the config folder location
$script:configEnvironmentRootPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($storageFileLocation, "Config"))

if($null -ne $env:ENVIRONMENT_MODULES_CONFIG) {
    $script:configEnvironmentRootPath = $env:ENVIRONMENT_MODULES_CONFIG
}
else {
    $env:ENVIRONMENT_MODULES_CONFIG = $script:configEnvironmentRootPath
}

mkdir $script:configEnvironmentRootPath -Force

# Setup the variables
$script:configuration = @{} # Configuration parameters
$script:loadedEnvironmentModules = @{} # ShortName -> ModuleInfo
$script:loadedEnvironmentModuleAliases = @{} # AliasName -> EnvironmentModuleAliasInfo[]
$script:loadedEnvironmentModuleFunctions = @{} # FunctionName -> EnvironmentModuleFunctionInfo[]
$script:environmentModuleParameters = @{} # ParameterName -> EnvironmentModuleParameterInfo

$script:environmentModules = @{} # FullName -> ModuleInfoBase
$script:customSearchPaths = New-Object "System.Collections.Generic.Dictionary[String, System.Collections.Generic.List[EnvironmentModuleCore.SearchPath]]"
$script:silentUnload = $false # Indicates if output should be printed on module unload
$script:silentLoad = $false # Indicates if output should be printed on module load

# Initialialize the configuration
. (Join-Path $PSScriptRoot "Configuration.ps1")
$script:configurationFilePath = (Join-Path $script:configEnvironmentRootPath "Configuration.xml")
Import-EnvironmentModulesConfiguration $script:configurationFilePath

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
if(test-path $script:searchPathsFileLocation)
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