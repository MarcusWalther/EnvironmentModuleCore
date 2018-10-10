function Get-EnvironmentModule([String] $ModuleFullName = "*", [switch] $ListAvailable, [string] $Architecture = "*", [string] $Version = "*")
{
    <#
    .SYNOPSIS
    Get the environment module object(s) matching the defined filters.
    .DESCRIPTION
    This function will return any environment modules that matches the given filter attributes.
    .PARAMETER ModuleFullName
    The full module name of the required module object(s). Can contain wildcards.
    .PARAMETER ListAvailable
    Show all environment modules that are available on the system.
    .PARAMETER Architecture
    Show only modules matching the given architecture.
    .PARAMETER Version
    Show only modules matching the given version.    
    .OUTPUTS
    The EnvironmentModule-object(s) matching the filter. If no module was found, $null is returned.
    #>
    if($ListAvailable) {
        foreach($module in Get-AllEnvironmentModules) {
            if(-not ($module.FullName -like $ModuleFullName)) {
                continue
            }

            if(($null -ne $module.Architecture) -and (-not ($module.Architecture -like $Architecture))) {
                continue
            }

            if(($null -ne $module.Version) -and (-not ($module.Version -like $Version))) {
                continue
            }            

            $result = New-EnvironmentModuleInfo -ModuleFullName $module.FullName     
            $result
        }
    }
    else {
        $filteredResult = $script:loadedEnvironmentModules.GetEnumerator() | Where-Object {$_.Value.FullName -like $ModuleFullName} | Select-Object -ExpandProperty "Value"
        $filteredResult = $filteredResult | Where-Object {(($null -eq $_.Version) -or ($_.Version -like $Version)) -and (($null -eq $_.Architecture) -or ($_.Architecture -like $Architecture))}

        return $filteredResult
    }
}

function Test-IsEnvironmentModuleLoaded([String] $ModuleFullName)
{
    <#
    .SYNOPSIS
    Check if the environment module with the given name is already loaded.
    .DESCRIPTION
    This function will check if Import-Module was called for an enivronment module with the given name.
    .PARAMETER ModuleFullName
    The full name of the module that should be tested.
    .OUTPUTS
    $true if the environment module was already loaded, otherwise $false.
    #>
    $loadedModule = (Get-EnvironmentModule $ModuleFullName)
    if(-not $loadedModule) {
        return $false
    }
        
    return $true
}

#TODO: Create a function Get-LoadedEnvironmentModules replacing '$script:loadedEnvironmentModules.Values...'

function Get-AllEnvironmentModules()
{
    <#
    .SYNOPSIS
    Get all known environment modules.
    .OUTPUTS
    All environment modules.
    #>
    return $script:environmentModules
}

function Get-ConcreteEnvironmentModules()
{
    <#
    .SYNOPSIS
    Get all environment modules that are not abstract (that can be loaded by the user).
    .OUTPUTS
    All concrete environment modules.
    #>    
    return Get-AllEnvironmentModules | Where-Object {$_.ModuleType -ne [EnvironmentModules.EnvironmentModuleType]::Abstract} | Select-Object -ExpandProperty "FullName"
}

function Get-EnvironmentModuleFunctionModules([String] $FunctionName)
{
    <#
    .SYNOPSIS
    Get all loaded modules that define a function with the given name.
    .DESCRIPTION
    This function will search the function stack for functions defined with the passed name.
    .PARAMETER FunctionName
    The name of the function.
    .OUTPUTS
    The list of modules defining the function. The last function in the list is the executed one.
    #>
    $result = New-Object "System.Collections.Generic.List[string]"
    if(-not $script:loadedEnvironmentModuleFunctions.ContainsKey($FunctionName))
    {
        return $result
    }

    foreach($knownFunction in $script:loadedEnvironmentModuleFunctions[$FunctionName]) {
        $result.Add($knownFunction.Item2)
    }

    return $result  
}

function Invoke-EnvironmentModuleFunction([String] $FunctionName, [String] $ModuleFullName, [Object[]] $ArgumentList)
{
    <#
    .SYNOPSIS
    Invoke the given function as specified by the given module.
    .PARAMETER FunctionName
    The name of the function to execute.
    .PARAMETER ModuleFullName
    The name of the module that defines the function.    
    .PARAMETER ArgumentList
    The arguments that should be passed to the function execution.
    .OUTPUTS
    The result of the function execution. An exception is thrown if the module does not define a function with the given name.
    #>    
    if(-not $script:loadedEnvironmentModuleFunctions.ContainsKey($FunctionName))
    {
        throw "The function $FunctionName is not registered"
    }

    $knownFunctionPairs = $script:loadedEnvironmentModuleFunctions[$FunctionName]

    foreach($functionPair in $knownFunctionPairs) {
        if($functionPair.Item2 -eq $ModuleFullName) {
            return Invoke-Command -ScriptBlock $functionPair.Item1 -ArgumentList $ArgumentList
        }
    }

    throw "The module $Module has no function registered named $Name"
}

function Get-EnvironmentModuleAlias
{
    $modules = $script:loadedEnvironmentModules.Values
    $aliases = @()

    foreach($module in $modules) {
        $aliases = $module.Aliases
        Write-Verbose "Handling module '$module' with $($aliases.Count) aliases"
        foreach($alias in $aliases.Keys) {
            $definition = $aliases[$alias]
            New-Object "EnvironmentModules.EnvironmentModuleAliasInfo" -ArgumentList @($alias, $module.FullName, $definition.Item1, $definition.Item2)
        }
    }
}