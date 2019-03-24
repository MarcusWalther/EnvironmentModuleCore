
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

        Write-Verbose "Identified $($Module.Paths.Length) paths"
        foreach ($pathInfo in $Module.Paths)
        {
            [String] $joinedValue = $pathInfo.Values -join [IO.Path]::PathSeparator
            Write-Verbose "Handling path for variable $($pathInfo.Variable) with values '$joinedValue'"
            if($joinedValue -eq "")  {
                continue
            }

            if ($pathInfo.PathType -eq [EnvironmentModuleCore.PathType]::PREPEND) {
                $pathInfo.Values | ForEach-Object {Remove-EnvironmentVariableValue -Variable $pathInfo.Variable -Value $_}
            }
            if ($pathInfo.PathType -eq [EnvironmentModuleCore.PathType]::APPEND) {
                $pathInfo.Values | ForEach-Object {Remove-EnvironmentVariableValue -Variable $pathInfo.Variable -Value $_ -Reverse}
            }
            if ($pathInfo.PathType -eq [EnvironmentModuleCore.PathType]::SET) {
                [Environment]::SetEnvironmentVariable($pathInfo.Variable, $null, "Process")
            }
        }

        foreach ($alias in $Module.Aliases.Keys) {
            Remove-Item alias:$alias
        }

        foreach ($functionInfo in $Module.Functions.Values) {
            Remove-EnvironmentModuleFunction $functionInfo
        }

        $loadedEnvironmentModules.Remove($Module.Name)
        Write-Verbose ("Removing " + $Module.Name + " from list of loaded environment variables")

        Write-Verbose "Removing module $($Module.FullName)"
        Remove-Module $Module.FullName -Force

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
    .PARAMETER Value
    The new value that should be removed from the environment variable.
    .PARAMETER Reverse
    The last occurence will be removed if this value is set.
    .OUTPUTS
    No output is returned.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [String] $Variable,
        [String] $Value,
        [Switch] $Reverse
    )

    $oldValue = [environment]::GetEnvironmentVariable($Variable,"Process")
    if($null -eq $oldValue) {
        return
    }
    Write-Verbose "Removing value '$Value' from environment variable '$Variable'. Reverse search is set to '$Reverse'"
    [System.Collections.Generic.List[string]] $allPathValues = $oldValue.Split([IO.Path]::PathSeparator)
    if($Reverse) {
        for($i = $allPathValues.Count; $i -gt 0; $i++) {
            if($_ -eq $Value) {
                $allPathValues.RemoveAt($i)
                break
            }
        }
    }
    else {
        for($i = 0; $i -lt $allPathValues.Count; $i++) {
            if($_ -eq $Value) {
                $allPathValues.RemoveAt($i)
                break
            }
        }
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
            $script:loadedEnvironmentModuleFunctions.Remove($FunctionDefinition.Name)
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