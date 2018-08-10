function Find-RootDirectory([EnvironmentModules.EnvironmentModuleBase] $Module) {
    <#
    .SYNOPSIS
    Find the root directory of the module, that is either specified by a registry entry or by a path.
    .DESCRIPTION
    This function will check the meta parameter of the given module and will identify the root directory of the module, either by its registry or path parameters.
    .PARAMETER Module
    The module to handle.
    .OUTPUTS
    The path to the root directory.
    #>
    return ""
}

function Import-EnvironmentModule
{
    <#
    .SYNOPSIS
    Import the environment module.
    .DESCRIPTION
    This function will import the environment module into the scope of the console.
    .PARAMETER Name
    The name of the environment module.
    .OUTPUTS
    No outputs are returned.
    #>
    [CmdletBinding()]
    Param(
        # Any other parameters can go here
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
    
        $arrSet = $script:environmentModules
        if($arrSet.Length -gt 0) {
            # Generate and set the ValidateSet 
            $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
        
            # Add the ValidateSet to the attributes collection
            $AttributeCollection.Add($ValidateSetAttribute)
        }
    
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
        Import-RequiredModulesRecursive -FullName $Name -LoadedDirectly $True
    }
}

function Import-RequiredModulesRecursive([String] $FullName, [Bool] $LoadedDirectly)
{
    <#
    .SYNOPSIS
    Import the environment module with the given name and all required environment modules.
    .DESCRIPTION
    This function will import the environment module into the scope of the console and will later iterate over all required modules to import them as well.
    .PARAMETER FullName
    The name of the environment module to import.
    .OUTPUTS
    No outputs are returned.
    #>
    Write-Verbose "Importing the module $Name recursive"
    
    $moduleInfos = Split-EnvironmentModuleName $FullName
    $name = $moduleInfos[0]
    
    if($script:loadedEnvironmentModules.ContainsKey($name)) {
        $module = $script:loadedEnvironmentModules.Get_Item($name)
        Write-Verbose "The module $name has loaded directly state $($module.IsLoadedDirectly) and should be loaded with state $LoadedDirectly"
        if($module.IsLoadedDirectly -and $LoadedDirectly) {
            return;
        }
        Write-Verbose "The module $name is already loaded. Increasing reference counter"
        $module.IsLoadedDirectly = $True
        $module.ReferenceCounter++
        return;
    }

    # Load the dependencies first
    $module = Read-EnvironmentModuleDescriptionFile -Name $FullName

    $loadDependenciesDirectly = $false

    if($module.DirectUnload -eq $true) {
        $loadDependenciesDirectly = $LoadedDirectly
    }

    Write-Verbose "Children are loaded with directly state $loadDependenciesDirectly"
    foreach ($dependency in $module.RequiredEnvironmentModules) {
        Write-Verbose "Importing dependency $dependency"
        Import-RequiredModulesRecursive $dependency $loadDependenciesDirectly
    }    

    Write-Verbose "The module has direct unload state $($module.DirectUnload)"
    if($module.DirectUnload -eq $true) {
        [void] (New-Event -SourceIdentifier "EnvironmentModuleLoaded" -EventArguments $module, $LoadedDirectly)   
        return
    }

    try {
        # Identify the root directory of the module
        Find-RootDirectory $module
    }
    catch {
        return
    }

    # Load the module itself
    $module = New-Object "EnvironmentModules.EnvironmentModule" -ArgumentList ((Find-EnvironmentModuleRoot $module), $module)
    Write-Verbose "Importing the module $FullName into the Powershell environment"
    Import-Module $FullName -Scope Global -Force -ArgumentList $module
    Mount-EnvironmentModuleInternal $module
    Write-Verbose "Importing of module $FullName done"
    
    $isLoaded = Test-IsEnvironmentModuleLoaded $name
    
    if(!$isLoaded) {
        Write-Error "The module $FullName was not loaded successfully"
        $script:silentUnload = $true
        Remove-Module $FullName -Force
        $script:silentUnload = $false
        return
    }

    # Get the completely loaded module
    $module = $script:loadedEnvironmentModules.Get_Item($name)
    $module.IsLoadedDirectly = $LoadedDirectly

    [void] (New-Event -SourceIdentifier "EnvironmentModuleLoaded" -EventArguments $module, $LoadedDirectly)   
}

function Mount-EnvironmentModuleInternal([EnvironmentModules.EnvironmentModule] $Module)
{
    <#
    .SYNOPSIS
    Deploy all the aliases and environment variables that are stored in the given module object to the environment.
    .DESCRIPTION
    This function will export all aliases and environment variables that are defined in the given EnvironmentModule-object. An error 
    is written if the module conflicts with another module that is already loaded.
    .PARAMETER Module
    The module that should be deployed.
    .OUTPUTS
    A boolean value that is $true if the module was loaded successfully. Otherwise the value is $false.
    #>
    process {
        Write-Verbose "Try to load module '$($Module.Name)' with architecture '$($Module.Architecture)', Version '$($Module.Version)' and type '$($Module.ModuleType)'"
        
        if($loadedEnvironmentModules.ContainsKey($Module.Name))
        {
            Write-Verbose "The module name '$($Module.Name)' was found in the list of already loaded modules"
            if($loadedEnvironmentModules.Get_Item($Module.Name).Equals($Module)) {
                Write-Host ("The Environment-Module '" + (Get-EnvironmentModuleDetailedString $Module) + "' is already loaded.") -foregroundcolor "Red"
                return $false
            }
            else {
                Write-Host ("The module '" + (Get-EnvironmentModuleDetailedString $Module) + " conflicts with the already loaded module '" + (Get-EnvironmentModuleDetailedString $loadedEnvironmentModules.($Module.Name)) + "'") -foregroundcolor "Red"
                return $false
            }
        }
        
        foreach ($pathKey in $Module.PrependPaths.Keys)
        {
            [String] $joinedValue = $Module.PrependPaths[$pathKey] -join ';'
            if($joinedValue -eq "") 
            {
                continue
            }
            Write-Verbose "Joined Prepend-Path: $pathKey = $joinedValue"
            Add-EnvironmentVariableValue -Variable "$pathKey" -Value "$joinedValue" -Append $false          
        }
        
        foreach ($pathKey in $Module.AppendPaths.Keys)
        {
            [String] $joinedValue = $Module.AppendPaths[$pathKey] -join ';'
            if($joinedValue -eq "") 
            {
                continue
            }
            Write-Verbose "Joined Append-Path: $pathKey = $joinedValue"
            Add-EnvironmentVariableValue -Variable "$pathKey" -Value "$joinedValue" -Append $true           
        }
        
        foreach ($pathKey in $Module.SetPaths.Keys)
        {
            [String] $joinedValue = $Module.SetPaths[$pathKey] -join ';'
            Write-Verbose "Joined Set-Path: $pathKey = $joinedValue"
            [Environment]::SetEnvironmentVariable($pathKey, $joinedValue, "Process")
        }
        
        foreach ($alias in $Module.Aliases.Keys) {
            $aliasValue = $Module.Aliases[$alias]

            Add-EnvironmentModuleAlias $alias $Module.FullName $aliasValue.Item1

            Set-Alias -name $alias -value $aliasValue.Item1 -scope "Global"
            if($aliasValue.Item2 -ne "") {
                Write-Host $aliasValue.Item2 -foregroundcolor "Green"
            }
        }
        
        Write-Verbose ("Register environment module with name " + $Module.Name + " and object " + $Module)
        
        Write-Verbose "Adding module $($Module.Name) to mapping"
        $script:loadedEnvironmentModules[$Module.Name] = $Module

        $Module.Load()
        Write-Host ((Get-EnvironmentModuleDetailedString $Module) + " loaded") -foregroundcolor "Yellow"
        return $true
    }
}