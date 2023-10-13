
function Remove-EnvironmentModule
{
    <#
    .SYNOPSIS
    Remove the environment module that was previously imported
    .DESCRIPTION
    This function will remove the environment module from the scope of the console.
    .PARAMETER ModuleFullName
    The name of the environment module to remove.
    .PARAMETER Force
    If this value is set, the module is unloaded even if other modules depend on it. If the delete flag is specified, no conformation
    is required if the Force flag is set.
    .PARAMETER Delete
    If this value is set, the module is deleted from the file system.
    .PARAMETER SkipCacheUpdate
    Only relevant if the delete flag is specified. If SkipCacheUpdate is passed, the Update-EnvironmentModule function is not called.
    .OUTPUTS
    No outputs are returned.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    Param(
        [switch] $Force,
        [switch] $Delete,
        [switch] $SkipCacheUpdate
    )
    DynamicParam {
        $runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $validationSet = @()

        if($Delete) {
            $validationSet = $script:environmentModules.Keys
        }
        else {
            $validationSet = Get-LoadedEnvironmentModules | Select-Object -ExpandProperty FullName
        }

        Add-DynamicParameter 'ModuleFullName' String $runtimeParameterDictionary -Mandatory $True -Position 0 -ValidateSet $validationSet
        return $runtimeParameterDictionary
    }

    begin {
        # Bind the parameter to a friendly variable
        $ModuleFullName = $PsBoundParameters['ModuleFullName']
    }

    process {
        if(Test-EnvironmentModuleLoaded $ModuleFullName) {
            Remove-RequiredModulesRecursive -ModuleFullName $ModuleFullName -UnloadedDirectly $True -Force $Force
        }

        if($Delete) {
            if(-not $Force) {
                $result = Show-ConfirmDialogue "Would you really like to delete the environment module '$ModuleFullName' from the file system?"
                if(-not $result) {
                    return
                }
            }

            $module = Get-EnvironmentModule -ListAvailable $ModuleFullName

            if(-not $module) {
                return
            }

            Remove-Item -Recurse -Force $module.ModuleBase

            if(-not $SkipCacheUpdate) {
                Update-EnvironmentModuleCache
            }
        }
    }
}

function Remove-RequiredModulesRecursive
{
    <#
    .SYNOPSIS
    Remove the environment module with the given name from the environment.
    .DESCRIPTION
    This function will remove the environment module from the scope of the console and will later iterate over all required modules to remove them as well.
    .PARAMETER ModuleFullName
    The full name of the environment module to remove.
    .PARAMETER UnloadedDirectly
    This value indicates if the module was unloaded by the user (directly) or if it was a dependency with reference counter decreased to 0 (indirectly).
    .PARAMETER Force
    If this value is set, the module is unloaded even if other modules depend on it.
    .OUTPUTS
    No outputs are returned.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [String] $ModuleFullName,
        [Bool] $UnloadedDirectly,
        [switch] $Force
    )
    $name = (Split-EnvironmentModuleName $ModuleFullName).Name

    if(!$script:loadedEnvironmentModules.ContainsKey($name)) {
        Write-InformationColored -InformationAction 'Continue' "Module $name not found"
        return
    }

    $module = $script:loadedEnvironmentModules.Get_Item($name)

    if(!$Force -and $UnloadedDirectly -and !$module.IsLoadedDirectly) {
        Write-Error "Unable to remove module $Name because it was imported as dependency"
        return
    }

    $module.ReferenceCounter--

    Write-Verbose "The module $($module.Name) has now a reference counter of $($module.ReferenceCounter)"

    foreach ($refModule in $module.Dependencies) {
        Remove-RequiredModulesRecursive $refModule.ModuleFullName $False
    }

    if($module.ReferenceCounter -le 0) {
        Write-Verbose "Removing Module $($module.Name)"
        Dismount-EnvironmentModule -Module $module
    }
}

function Dismount-EnvironmentModule([EnvironmentModuleCore.EnvironmentModule] $Module, [switch] $SuppressOutput)
{
    <#
    .SYNOPSIS
    Remove all the aliases and environment variables that are stored in the given module object from the environment.
    .DESCRIPTION
    This function will remove all aliases and environment variables that are defined in the given EnvironmentModule-object from the environment. An error
    is written if the module was not loaded. Either specify the concrete environment module object or the name of the environment module you want to remove.
    .PARAMETER Module
    The module that should be removed.
    #>
    process {
        if(!$loadedEnvironmentModules.ContainsKey($Module.Name))
        {
            Write-InformationColored -InformationAction 'Continue' ("The Environment-Module $inModule is not loaded.") -ForegroundColor $Host.PrivateData.ErrorForegroundColor -BackgroundColor $Host.PrivateData.ErrorBackgroundColor
            return
        }

        Write-Verbose "Identified $($Module.Paths.Count) paths"
        foreach ($pathInfo in $Module.Paths)
        {
            [String] $joinedValue = $pathInfo.Values -join [IO.Path]::PathSeparator
            Write-Verbose "Handling path for variable $($pathInfo.Variable) with values '$joinedValue'"
            if($joinedValue -eq "")  {
                continue
            }

            if ($pathInfo.PathType -eq [EnvironmentModuleCore.PathType]::PREPEND) {
                $pathInfo.Values | ForEach-Object {Remove-EnvironmentVariableValue -Variable $pathInfo.Variable -ModuleValue $_}
            }
            if ($pathInfo.PathType -eq [EnvironmentModuleCore.PathType]::APPEND) {
                $pathInfo.Values | ForEach-Object {Remove-EnvironmentVariableValue -Variable $pathInfo.Variable -ModuleValue $_ -Reverse}
            }
            if ($pathInfo.PathType -eq [EnvironmentModuleCore.PathType]::SET) {
                $previousValue = $script:loadedEnvironmentModuleSetPaths[$Module.FullName]
                $newValue = $null
                if($null -ne $previousValue) {
                    $previousValue = $previousValue[$pathInfo.Variable]

                    if($null -ne $previousValue) {
                        $actualValue = [Environment]::GetEnvironmentVariable($pathInfo.Variable)
                        if($actualValue -ne $joinedValue) {
                            $newValue = $actualValue
                        }
                        else {
                            $newValue = $previousValue
                        }
                    }
                    else {
                        Write-Warning "Unable to find previous set path value for variable '$($pathInfo.Variable)' and module '$($Module.FullName)'"
                    }
                }
                else {
                    Write-Warning "Unable to find previous set path values for module '$($Module.FullName)'"
                }

                [Environment]::SetEnvironmentVariable($pathInfo.Variable, $newValue, "Process")
            }
        }

        $script:loadedEnvironmentModuleSetPaths.Remove($Module.FullName) | out-null

        foreach ($alias in $Module.Aliases.Keys) {
            Remove-EnvironmentModuleAlias $Module.Aliases[$alias]
        }

        foreach ($functionInfo in $Module.Functions.Values) {
            Remove-EnvironmentModuleFunction $functionInfo
        }

        foreach ($parameter in $Module.Parameters.Keys) {
            Remove-EnvironmentModuleParameterInternal $parameter.Item1
        }
        Update-VirtualParameterEnvironments

        $loadedEnvironmentModules.Remove($Module.Name) | out-null
        Write-Verbose ("Removing " + $Module.Name + " from list of loaded environment variables")

        Write-Verbose "Removing module $($Module.FullName)"
        Remove-Module $Module.FullName -Force

        $Module.FullyUnloaded()
        if($script:configuration["ShowLoadingMessages"] -and (-not $script:silentUnload)) {
            Write-InformationColored -InformationAction 'Continue' ($Module.Name + " unloaded") -Foregroundcolor $Host.PrivateData.VerboseForegroundColor -BackgroundColor $Host.PrivateData.VerboseBackgroundColor
        }

        return
    }
}

function Remove-EnvironmentVariableValue
{
    <#
    .SYNOPSIS
    Remove the given value from the desired environment variable.
    .DESCRIPTION
    This function will remove the given value from the environment variable with the given name. If the value is not part
    of the environment variable, no changes are performed.
    .PARAMETER Variable
    The name of the environment variable that should be extended.
    .PARAMETER ModuleValue
    The value that was added by the module and that should be removed from the environment variable.
    .PARAMETER Reverse
    The last occurence will be removed if this value is set.
    .OUTPUTS
    No output is returned.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [String] $Variable,
        [String] $ModuleValue,
        [Switch] $Reverse
    )

    $actualValue = [environment]::GetEnvironmentVariable($Variable,"Process")
    if(($null -eq $actualValue) -or ($null -eq $ModuleValue)) {
        return
    }
    Write-Verbose "Removing value '$ModuleValue' from environment variable '$Variable'. Reverse search is set to '$Reverse'"

    $actualValuePartsMapping = [System.Collections.Generic.Dictionary[string, int]]::new()  # Mapping of each PATH value to its index
    [System.Collections.Generic.List[string]] $allPathValues = $actualValue.Split([IO.Path]::PathSeparator)

    # Setup the parts mapping
    $index = 0
    foreach($part in $allPathValues) {
        if(-not $actualValuePartsMapping.ContainsKey($part)) {
            $actualValuePartsMapping[$part] = $index
        }
        else {
            if($Reverse) {
                $actualValuePartsMapping[$part] = $index
            }
        }
        $index += 1
    }

    # Fill the indices to remove
    $indicesToRemove = [System.Collections.Generic.List[string]]::new()
    foreach($part in $ModuleValue.Split([IO.Path]::PathSeparator)) {
        if(-not $actualValuePartsMapping.ContainsKey($part)) {
            Write-Verbose "The PATH value '$part' is not part of the variable '$Variable' anymore"
            continue
        }

        $indicesToRemove.Add($actualValuePartsMapping[$part])
    }

    $indicesToRemove.Sort()
    $indicesToRemove.Reverse()

    foreach($index in $indicesToRemove) {
        $allPathValues.RemoveAt($index)
    }

    $newValue = ($allPathValues -join [IO.Path]::PathSeparator)
    [Environment]::SetEnvironmentVariable($Variable, $newValue, "Process")
}

function Remove-EnvironmentModuleFunction
{
    <#
    .SYNOPSIS
    Remove a function from the active environment stack.
    .DESCRIPTION
    This function will remove the given function from the active environment. The function is removed from the loaded functions stack.
    .PARAMETER FunctionDefinition
    The definition of the function.
    .OUTPUTS
    No output is returned.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param (
        [EnvironmentModuleCore.FunctionInfo] $FunctionDefinition
    )

    # Check if the function was already used
    if($script:loadedEnvironmentModuleFunctions.ContainsKey($FunctionDefinition.Name))
    {
        $knownFunctions = $script:loadedEnvironmentModuleFunctions[$FunctionDefinition.Name]
        $knownFunctions.Remove($FunctionDefinition) | out-null
        if($knownFunctions.Count -eq 0) {
            $script:loadedEnvironmentModuleFunctions.Remove($FunctionDefinition.Name) | out-null
            Remove-Item -path "function:\$($FunctionDefinition.Name)" | out-null
        }
    }
}

function Remove-EnvironmentModuleAlias
{
    <#
    .SYNOPSIS
    Remove a alias from the active environment stack.
    .DESCRIPTION
    This function will remove the given alias from the active environment stack.
    .PARAMETER FunctionDefinition
    The definition of the alias.
    .OUTPUTS
    No output is returned.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param (
        [EnvironmentModuleCore.AliasInfo] $AliasInfo
    )

    # Check if the function was already used
    if($script:loadedEnvironmentModuleAliases.ContainsKey($AliasInfo.Name))
    {
        $knownFunctions = $script:loadedEnvironmentModuleAliases[$AliasInfo.Name]
        $knownFunctions.Remove($AliasInfo) | out-null
        if($knownFunctions.Count -eq 0) {
            $script:loadedEnvironmentModuleAliases.Remove($AliasInfo.Name) | out-null
            Remove-Item alias:$alias | out-null
        }
    }
}

function Clear-EnvironmentModules([Switch] $Force)
{
    <#
    .SYNOPSIS
    Remove all loaded environment modules from the environment.
    .DESCRIPTION
    This function will remove all loaded environment modules, so that a clean environment module remains.
    .PARAMETER Force
    If this value is set, the user is not asked for module unload.
    .OUTPUTS
    No output is returned.
    #>

    $modules = Get-EnvironmentModule

    if($modules -and (-not $Force)) {
        $result = Show-ConfirmDialogue "Do you really want to remove all loaded environment modules?"
        if(-not $result) {
            return
        }
    }

    foreach($module in $modules) {
        if($module.IsLoadedDirectly) {
            Remove-EnvironmentModule $module.FullName -Force
        }
    }
}