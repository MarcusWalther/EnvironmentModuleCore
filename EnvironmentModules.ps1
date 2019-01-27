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

            New-EnvironmentModuleInfo -ModuleFullName $module.FullName
        }
    }
    else {
        $filteredResult = $script:loadedEnvironmentModules.GetEnumerator() | Where-Object {$_.Value.FullName -like $ModuleFullName} | Select-Object -ExpandProperty "Value"
        $filteredResult = $filteredResult | Where-Object {(($null -eq $_.Version) -or ($_.Version -like $Version)) -and (($null -eq $_.Architecture) -or ($_.Architecture -like $Architecture))}

        return $filteredResult
    }
}

function Test-EnvironmentModuleLoaded([String] $ModuleFullName)
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

function Get-LoadedEnvironmentModules()
{
    <#
    .SYNOPSIS
    Get all loaded environment modules.
    .OUTPUTS
    All loaded environment modules.
    #>
    return $script:loadedEnvironmentModules.Values
}

function Get-AllEnvironmentModules()
{
    <#
    .SYNOPSIS
    Get all known environment modules.
    .OUTPUTS
    All environment modules.
    #>
    return $script:environmentModules.Values
}

function Get-NonTempEnvironmentModules()
{
    <#
    .SYNOPSIS
    Get all environment modules that are not stored in the temp folder.
    .OUTPUTS
    All non temp environment modules.
    #>
    return Get-AllEnvironmentModules | Where-Object { -not(Test-PartOfTmpDirectory $_.PSModuleInfo.ModuleBase) }
}

function Get-ConcreteEnvironmentModules()
{
    <#
    .SYNOPSIS
    Get all environment modules that are not abstract (that can be loaded by the user).
    .OUTPUTS
    All concrete environment modules.
    #>
    return Get-AllEnvironmentModules | Where-Object {$_.ModuleType -ne [EnvironmentModules.EnvironmentModuleType]::Abstract}
}

function Get-EnvironmentModuleFunction([String] $FunctionName = "*", [String] $ModuleFullName = "*")
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
    foreach($info in $script:loadedEnvironmentModuleFunctions.Values) {
        if(($info.ModuleFullName -like $ModuleFullName) -and ($info.Name -like $FunctionName)) {
            $info
        }
    }
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

    $knownFunctions = $script:loadedEnvironmentModuleFunctions[$FunctionName]

    foreach($functionInfo in $knownFunctions) {
        if($functionInfo.ModuleFullName -eq $ModuleFullName) {
            return Invoke-Command -ScriptBlock $functionInfo.Definition -ArgumentList $ArgumentList
        }
    }

    throw "The module $ModuleFullName has no function registered named $FunctionName"
}

function Get-EnvironmentModuleAlias([String] $ModuleFullName = "*", [String] $AliasName = "*")
{
    <#
    .SYNOPSIS
    Get all aliases that are loaded in the current environment.
    .PARAMETER ModuleFullName
    The name of the modules that should be investigated. Wildcards are allowed.
    .PARAMETER AliasName
    The name of the aliases to investigate. Wildcards are allowed.
    .OUTPUTS
    An array of EnvironmentModules.EnvironmentModuleAliasInfo objects.
    #>
    $modules = Get-LoadedEnvironmentModules

    foreach($module in $modules) {
        if(-not ($module.FullName -like $ModuleFullName)) {
            continue
        }
        $aliases = $module.Aliases
        Write-Verbose "Handling module '$module' with $($aliases.Count) aliases"
        foreach($alias in $aliases.Keys) {
            if(-not ($alias -like $AliasName)) {
                continue
            }
            $definition = $aliases[$alias]
            New-Object "EnvironmentModules.EnvironmentModuleAliasInfo" -ArgumentList @($alias, $module.FullName, $definition.Definition, $definition.Description)
        }
    }
}

function Get-EnvironmentModulePath([String] $ModuleFullName = "*", [String] $PathName = "*", [EnvironmentModules.EnvironmentModulePathType] $PathType = [EnvironmentModules.EnvironmentModulePathType]::UNKNOWN)
{
    <#
    .SYNOPSIS
    Get all paths that are loaded in the current environment.
    .PARAMETER ModuleFullName
    The name of the modules that should be investigated. Wildcards are allowed.
    .PARAMETER PathName
    The name of the environment variables to investigate. Wildcards are allowed.
    .PARAMETER PathType
    The type of the paths to investigate. UNKNOWN if all types should be considered.
    .OUTPUTS
    An array of EnvironmentModules.EnvironmentModuleAliasInfo objects.
    #>
    $modules = Get-LoadedEnvironmentModules

    foreach($module in $modules) {
        if(-not ($module.FullName -like $ModuleFullName)) {
            continue
        }
        $paths = $module.Paths
        Write-Verbose "Handling module '$module' with $($paths.Count) paths"
        foreach($pathInfo in $paths) {
            if(-not ($pathInfo.Variable -like $PathName)) {
                continue
            }
            if(([EnvironmentModules.EnvironmentModulePathType]::UNKNOWN -ne $PathType) -and ($pathInfo.PathType -ne $PathType)) {
                continue
            }

            $pathInfo
        }
    }
}