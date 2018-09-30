function Get-EnvironmentModule([String] $Name = "*", [switch] $ListAvailable, [string] $Architecture = "*", [string] $Version = "*")
{
    <#
    .SYNOPSIS
    Get the environment module object, loaded by the given module name.
    .DESCRIPTION
    This function will check if an environment module with the given name was loaded and will return it. The 
    name is just the name of the module, without version, architecture or other information.
    .PARAMETER Name
    The module name of the required module object.
    .PARAMETER ListAvailable
    Show all environment modules that are available on the system.
    .OUTPUTS
    The EnvironmentModule-object if a module with the given name was already loaded. If no module with 
    name was found, $null is returned.
    #>
    if($ListAvailable) {
        foreach($module in Get-AllEnvironmentModules) {
            if(-not ($module.FullName -like $Name)) {
                continue
            }

            if(($null -ne $module.Architecture) -and (-not ($module.Architecture -like $Architecture))) {
                continue
            }

            if(($null -ne $module.Version) -and (-not ($module.Version -like $Version))) {
                continue
            }            

            $result = New-EnvironmentModuleInfo -Name $module.FullName     
            $result
        }
    }
    else {
        $filteredResult = $loadedEnvironmentModules.GetEnumerator() | Where-Object {$_.Value.FullName -like $Name} | Select-Object -ExpandProperty "Value"
        $filteredResult = $filteredResult | Where-Object {(($null -eq $_.Version) -or ($_.Version -like $Version)) -and (($null -eq $_.Architecture) -or ($_.Architecture -like $Architecture))}

        return $filteredResult
    }
}

function Get-EnvironmentModuleDetailedString([EnvironmentModules.EnvironmentModule] $Module)
{
    <#
    .SYNOPSIS
    This is the reverse function of Split-EnvironmentModuleName. It will convert the information stored in 
    the given EnvironmentModule-object to a String containing Name, Version, Architecture and additional options.
    .DESCRIPTION
    Convert the given EnvironmentModule to a String with the form Name-Version[Architecture]-AdditionalOptions.
    .PARAMETER Module
    The module that should be converted to a String.
    .OUTPUTS
    A string with the form Name-Version[Architecture]-AdditionalOptions.
    #>
    $resultString = $Module.Name
    Write-Verbose "Creating detailed string with name $($Module.Name)"
    if($Module.Version) {
        $resultString += "-" + $Module.Version
        Write-Verbose "Adding version to detailed string with value $($Module.Version)"
    }
    if($Module.Architecture) {
        $resultString += '-' + $Module.Architecture
        Write-Verbose "Adding architecture to detailed string with value $($Module.Architecture)"
    }
    if($Module.AdditionalInfo) {
        $resultString += '-' + $Module.AdditionalInfo
        Write-Verbose "Adding additional information to detailed string with value $($Module.AdditionalInfo)"
    }    
    return $resultString
}

function Get-LoadedEnvironmentModulesFullName()
{
    <#
    .SYNOPSIS
    Get all loaded environment modules with full name.
    .DESCRIPTION
    This function will return a String list, containing the names of all loaded environment modules.
    .OUTPUTS
    The String list containing the names of all environment modules.
    #>
    [String[]]$values = $loadedEnvironmentModules.getEnumerator() | % { Get-EnvironmentModuleDetailedString($_.Value) }
    return $values
}

function Test-IsEnvironmentModuleLoaded([String] $Name)
{
    <#
    .SYNOPSIS
    Check if the environment module with the given name is already loaded.
    .DESCRIPTION
    This function will check if Import-Module was called for an enivronment module with the given name.
    .PARAMETER Name
    The name of the module that should be tested.
    .OUTPUTS
    $true if the environment module was already loaded, otherwise $false.
    #>
    $loadedModule = (Get-EnvironmentModule $Name)
    if(!$loadedModule) {
        return $false
    }
        
    return $true
}

function Get-AllEnvironmentModules()
{
    return $script:environmentModules
}

function Get-ConcreteEnvironmentModules()
{
    return $script:environmentModules | Where-Object {$_.ModuleType -ne [EnvironmentModules.EnvironmentModuleType]::Abstract} | Select-Object -ExpandProperty "FullName"
}

function Get-EnvironmentModuleFunctionModules([String] $Name)
{
    <#
    .SYNOPSIS
    Get all loaded modules that define a function with the given name.
    .DESCRIPTION
    This function will search the function stack for functions defined with the passed name.
    .PARAMETER Name
    The name of the function.
    .OUTPUTS
    The list of modules defining the function. The last function in the list is the executed one.
    #>
    $result = New-Object "System.Collections.Generic.List[string]"
    if(-not $script:loadedEnvironmentModuleFunctions.ContainsKey($Name))
    {
        return $result
    }

    foreach($knownFunction in $script:loadedEnvironmentModuleFunctions[$Name]) {
        $result.Add($knownFunction.Item2)
    }

    return $result  
}

function Invoke-EnvironmentModuleFunction([String] $Name, [String] $Module, [Object[]] $ArgumentList)
{
    if(-not $script:loadedEnvironmentModuleFunctions.ContainsKey($Name))
    {
        throw "The function $Name is not registered"
    }

    $knownFunctionPairs = $script:loadedEnvironmentModuleFunctions[$Name]

    foreach($functionPair in $knownFunctionPairs) {
        if($functionPair.Item2 -eq $Module) {
            return Invoke-Command -ScriptBlock $functionPair.Item1 -ArgumentList $ArgumentList
        }
    }

    throw "The module $Module has no function registered named $Name"
}