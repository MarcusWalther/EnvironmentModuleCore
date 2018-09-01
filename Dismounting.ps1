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
                Write-Host ("You must specify a module which should be removed, by either passing the name or the environment module object.") -foregroundcolor "Red"
            }
            $Module = (Get-EnvironmentModule $Name)
            if(!$Module) { return; }
        }
        
        if(!$loadedEnvironmentModules.ContainsKey($Module.Name))
        {
            Write-Host ("The Environment-Module $inModule is not loaded.") -foregroundcolor "Red"
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