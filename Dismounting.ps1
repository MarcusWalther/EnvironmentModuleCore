
function Remove-EnvironmentModule
{
    <#
    .SYNOPSIS
    Remove the environment module that was previously imported
    .DESCRIPTION
    This function will remove the environment module from the scope of the console.
    .PARAMETER Name
    The name of the environment module.
    .OUTPUTS
    No outputs are returned.
    #>
    [CmdletBinding()]
    Param(
        [switch] $Force
    )
    DynamicParam {
        # Set the dynamic parameters' name
        $ParameterName = 'Name'
        
        # Create the dictionary 
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
    
        # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        
        # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.Position = 0
    
        # Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)
    
        # Generate and set the ValidateSet 
        $arrSet = $script:loadedEnvironmentModules.Values | % {Get-EnvironmentModuleDetailedString $_}
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
    
        # Add the ValidateSet to the attributes collection
        $AttributeCollection.Add($ValidateSetAttribute)
    
        # Create and return the dynamic parameter
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }
    
    begin {
        # Bind the parameter to a friendly variable
        $Name = $PsBoundParameters[$ParameterName]
    }

    process {   
        Remove-RequiredModulesRecursive -FullName $Name -UnloadedDirectly $True -Force $Force
    }
}

function Remove-RequiredModulesRecursive([String] $FullName, [Bool] $UnloadedDirectly, [switch] $Force)
{
    <#
    .SYNOPSIS
    Remove the environment module with the given name from the environment.
    .DESCRIPTION
    This function will remove the environment module from the scope of the console and will later iterate over all required modules to remove them as well.
    .PARAMETER FullName
    The name of the environment module to remove.
    .OUTPUTS
    No outputs are returned.
    #>
    $moduleInfos = Split-EnvironmentModuleName $FullName
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
function Dismount-EnvironmentModule([String] $Name = $null, [EnvironmentModules.EnvironmentModule] $Module = $null)
{
    <#
    .SYNOPSIS
    Remove all the aliases and environment variables that are stored in the given module object from the environment.
    .DESCRIPTION
    This function will remove all aliases and environment variables that are defined in the given EnvironmentModule-object from the environment. An error 
    is written if the module was not loaded. Either specify the concrete environment module object or the name of the environment module you want to remove.
    .PARAMETER Name
    The name of the module that should be removed.
    .PARAMETER Module
    The module that should be removed.
    #>
    process {       
        if(!$Module) {
            if(!$Name) {
                Write-Host ("You must specify a module which should be removed, by either passing the name or the environment module object.") -ForegroundColor $Host.PrivateData.ErrorForegroundColor -BackgroundColor $Host.PrivateData.ErrorBackgroundColor
            }
            $Module = (Get-EnvironmentModule $Name)
            if(!$Module) { return; }
        }
        
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

        Write-Verbose "Removing module $(Get-EnvironmentModuleDetailedString $Module)"
        Remove-Module (Get-EnvironmentModuleDetailedString $Module) -Force
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
    $allPathValues = ($allPathValues | Where {$_.ToString() -ne $Value.ToString()})
    $newValue = ($allPathValues -join ";")
    [Environment]::SetEnvironmentVariable($Variable, $newValue, "Process")
}