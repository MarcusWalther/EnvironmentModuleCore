
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
    Param(
        [switch] $Force,
        [switch] $Delete,
        [Switch] $SkipCacheUpdate
    )
    DynamicParam {
        $runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        Add-DynamicParameter 'ModuleFullName' String $runtimeParameterDictionary -Mandatory $True -Position 0
        return $runtimeParameterDictionary
    }
    
    begin {
        # Bind the parameter to a friendly variable
        $ModuleFullName = $PsBoundParameters['ModuleFullName']
    }

    process {
        if(Test-IsEnvironmentModuleLoaded $ModuleFullName) {
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

# This argument completer is used by Remove-EnvironmentModule for the environment module filter
Register-ArgumentCompleter -CommandName Remove-EnvironmentModule -ParameterName ModuleFullName -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

    if($fakeBoundParameter["Delete"]) {
        $script:environmentModules.Values | Select-Object -ExpandProperty FullName
    }
    else {
        $script:loadedEnvironmentModules.Values | Select-Object -ExpandProperty FullName
    }
}

function Remove-RequiredModulesRecursive([String] $ModuleFullName, [Bool] $UnloadedDirectly, [switch] $Force)
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
    $moduleInfos = Split-EnvironmentModuleName $ModuleFullName
    $name = $moduleInfos[0]
    
    if(!$script:loadedEnvironmentModules.ContainsKey($name)) {
        Write-Host "Module $name not found"
        return;
    }
    
    $module = $script:loadedEnvironmentModules.Get_Item($name)
    
    if(!$Force -and $UnloadedDirectly -and !$module.IsLoadedDirectly) {
        Write-Error "Unable to remove module $Name because it was imported as dependency"
        return;
    }

    $module.ReferenceCounter--
    
    Write-Verbose "The module $($module.Name) has now a reference counter of $($module.ReferenceCounter)"
    
    foreach ($refModule in $module.RequiredEnvironmentModules) {
        Remove-RequiredModulesRecursive $refModule $False
    }   
    
    if($module.ReferenceCounter -le 0) {
        Write-Verbose "Removing Module $($module.Name)" 
        Dismount-EnvironmentModule -Module $module
    }   
}

function Dismount-EnvironmentModule([EnvironmentModules.EnvironmentModule] $Module)
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
            Write-Host ("The Environment-Module $inModule is not loaded.") -ForegroundColor $Host.PrivateData.ErrorForegroundColor -BackgroundColor $Host.PrivateData.ErrorBackgroundColor
            return
        }

        foreach ($pathKey in $Module.PrependPaths.Keys)
        {
            [String] $joinedValue = $Module.PrependPaths[$pathKey] -join ';'
            if($joinedValue -eq "") 
            {
                continue
            }
            Write-Verbose "Joined Prepend-Path: $pathKey = $joinedValue"
            Remove-EnvironmentVariableValue -Variable "$pathKey" -Value "$joinedValue"      
        }
        
        foreach ($pathKey in $Module.AppendPaths.Keys)
        {
            [String] $joinedValue = $Module.AppendPaths[$pathKey] -join ';'
            if($joinedValue -eq "") 
            {
                continue
            }
            Write-Verbose "Joined Append-Path: $pathKey = $joinedValue"
            Remove-EnvironmentVariableValue -Variable "$pathKey" -Value "$joinedValue"      
        }
        
        foreach ($pathKey in $Module.SetPaths.Keys)
        {
            [Environment]::SetEnvironmentVariable($pathKey, $null, "Process")
        }

        foreach ($alias in $Module.Aliases.Keys) {
            Remove-Item alias:$alias
        }

        $loadedEnvironmentModules.Remove($Module.Name)
        Write-Verbose ("Removing " + $Module.Name + " from list of loaded environment variables")

        Write-Verbose "Removing module $($Module.FullName)"
        Remove-Module $Module.FullName -Force
        if(-not $script:silentUnload) {
            Write-Host ($Module.Name + " unloaded") -foregroundcolor "Yellow"
        }
        
        return
    }
}

function Remove-EnvironmentVariableValue([String] $Variable, [String] $Value)
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
    .OUTPUTS
    No output is returned.
    #>
    $oldValue = [environment]::GetEnvironmentVariable($Variable,"Process")
    $allPathValues = $oldValue.Split(";")
    $allPathValues = ($allPathValues | Where-Object {$_.ToString() -ne $Value.ToString()})
    $newValue = ($allPathValues -join ";")
    [Environment]::SetEnvironmentVariable($Variable, $newValue, "Process")
}