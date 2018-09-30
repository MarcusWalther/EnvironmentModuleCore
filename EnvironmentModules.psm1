# Read the temp folder location
$moduleFileLocation = $MyInvocation.MyCommand.ScriptBlock.Module.Path
$script:tmpEnvironmentRootPath = ([IO.Path]::Combine($moduleFileLocation, "..\Tmp\"))

if($null -ne $env:ENVIRONMENT_MODULES_TMP) {
    $script:tmpEnvironmentRootPath = $env:ENVIRONMENT_MODULES_TMP
}

Write-Verbose "Using environment module temp path $($script:tmpEnvironmentRootPath)"
$script:tmpEnvironmentModulePath = ([IO.Path]::Combine($script:tmpEnvironmentRootPath, "Modules"))

mkdir $script:tmpEnvironmentRootPath -Force
mkdir $script:tmpEnvironmentModulePath -Force
$env:PSModulePath = "$env:PSModulePath;$script:tmpEnvironmentModulePath"

# Read the config folder location
$script:configEnvironmentRootPath = ([IO.Path]::Combine($moduleFileLocation, "..\Config\"))

if($null -ne $env:ENVIRONMENT_MODULES_CONFIG) {
    $script:configEnvironmentRootPath = $env:ENVIRONMENT_MODULES_CONFIG
}

mkdir $script:configEnvironmentRootPath -Force

# Setup the variables
$script:loadedEnvironmentModules = @{}
$script:loadedEnvironmentModuleAliases = @{} # AliasName -> (String, ModuleName)[]
$script:loadedEnvironmentModuleFunctions = @{} # FunctionName -> (String, ModuleName)[]

$script:environmentModules = @()
$script:customSearchPaths = New-Object "System.Collections.Generic.Dictionary[String, System.Collections.Generic.List[EnvironmentModules.SearchPath]]"
$script:silentUnload = $false

# Define the functions
function Get-AllEnvironmentModules()
{
    return $script:environmentModules
}

function Get-ConcreteEnvironmentModules()
{
    return $script:environmentModules | Where-Object {$_.ModuleType -ne [EnvironmentModules.EnvironmentModuleType]::Abstract} | Select-Object -ExpandProperty "FullName"
}

function Add-EnvironmentModuleAlias([String] $Name, [String] $Module, [String] $Definition)
{
    $newTupleValue = [System.Tuple]::Create($Definition, $Module)
    # Check if the alias was already used
    if($loadedEnvironmentModuleAliases.ContainsKey($Name))
    {
        $knownAliases = $loadedEnvironmentModuleAliases[$Name]
        $knownAliases.Add($newTupleValue)
    }
    else {
        $newValue = New-Object "System.Collections.Generic.List[System.Tuple[String, String]]"
        $newValue.Add($newTupleValue)
        $loadedEnvironmentModuleAliases.Add($Name, $newValue)
    }
}

function Add-EnvironmentModuleFunction([String] $Name, [String] $Module, [System.Management.Automation.ScriptBlock] $Definition)
{
    Write-Verbose $Module.ToString()
    $newTupleValue = [System.Tuple]::Create($Definition, $Module)
    # Check if the function was already used
    if($loadedEnvironmentModuleFunctions.ContainsKey($Name))
    {
        $knownFunctions = $loadedEnvironmentModuleFunctions[$Name]
        $knownFunctions.Add($newTupleValue)
    }
    else {
        $newValue = New-Object "System.Collections.Generic.List[System.Tuple[System.Management.Automation.ScriptBlock, String]]"
        $newValue.Add($newTupleValue)
        $loadedEnvironmentModuleFunctions.Add($Name, $newValue)
    }
}

function Get-EnvironmentModuleFunctions([String] $Name)
{
    $result = New-Object "System.Collections.Generic.List[string]"
    if(-not $loadedEnvironmentModuleFunctions.ContainsKey($Name))
    {
        return $result
    }

    foreach($knownFunction in $loadedEnvironmentModuleFunctions[$Name]) {
        $result.Add($knownFunction.Item2)
    }

    return $result  
}

function Invoke-EnvironmentModuleFunction([String] $Name, [String] $Module, [Object[]] $ArgumentList)
{
    if(-not $loadedEnvironmentModuleFunctions.ContainsKey($Name))
    {
        throw "The function $Name is not registered"
    }

    $knownFunctionPairs = $loadedEnvironmentModuleFunctions[$Name]

    foreach($functionPair in $knownFunctionPairs) {
        if($functionPair.Item2 -eq $Module) {
            return Invoke-Command -ScriptBlock $functionPair.Item1 -ArgumentList $ArgumentList
        }
    }

    throw "The module $Module has no function registered named $Name"
}

# Include all required functions
. "${PSScriptRoot}\Utils.ps1"

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

# Include the main code
. "${PSScriptRoot}\EnvironmentModules.ps1"