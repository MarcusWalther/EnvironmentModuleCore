function Test-FileExistence([string] $FolderPath, [string[]] $Files) {
    <#
    .SYNOPSIS
    Check if the given folder contains all files given as second parameter.
    .DESCRIPTION
    This function will check if the folder does exist and if it contains all given files.
    .PARAMETER FolderPath
    The folder to check.
    .PARAMETER Files
    The files to check.    
    .OUTPUTS
    True if the folder does exist and if it contains all files, false otherwise.
    #>

    if (-not (Test-Path $FolderPath)) {
        Write-Verbose "The folder $FolderPath does not exist"
        return $false
    }

    foreach($file in $Files) {
        if (-not (Test-Path (Join-Path $FolderPath $file))) {
            Write-Verbose "The file $file does not exist in folder $FolderPath"
            return $false
        }
    }

    return $true
}

function Find-RootDirectory([EnvironmentModules.EnvironmentModuleInfo] $Module) {
    <#
    .SYNOPSIS
    Find the root directory of the module, that is either specified by a registry entry or by a path.
    .DESCRIPTION
    This function will check the meta parameter of the given module and will identify the root directory of the module, either by its registry or path parameters.
    .PARAMETER Module
    The module to handle.
    .OUTPUTS
    The path to the root directory or $null if it was not found.
    #>

    foreach($searchPath in $Module.SearchPaths)
    {
        if($searchPath.GetType() -eq [EnvironmentModules.RegistrySearchPath]) {
            $pathSegments = $searchPath.Key.Split('\')
            $propertyName = $pathSegments[-1]
            $propertyPath = [string]::Join('\', $pathSegments[0..($pathSegments.Length - 2)])
    
            try {
                $registryValue = Get-ItemProperty -ErrorAction SilentlyContinue -Name "$propertyName" -Path "Registry::$propertyPath" | Select-Object -ExpandProperty "$propertyName"   
                if ($null -eq $registryValue) {
                    continue
                }
                if (Test-FileExistence (Split-Path -parent $registryValue) $Module.RequiredFiles) {
                    return (Split-Path -parent $registryValue)
                }
            }
            catch {
                continue
            }

            continue
        }

        if($searchPath.GetType() -eq [EnvironmentModules.DirectorySearchPath]) {
            if (Test-FileExistence $searchPath.Directory $Module.RequiredFiles) {
                return $searchPath.Directory
            }

            continue
        }
    }

    # # Search the registry paths
    # foreach($path in ($Module.CustomRegistryPaths + $Module.DefaultRegistryPaths)) {
    #     $pathSegments = $path.Split('\')
    #     $propertyName = $pathSegments[-1]
    #     $propertyPath = [string]::Join('\', $pathSegments[0..($pathSegments.Length - 2)])

    #     try {
    #         $registryValue = Get-ItemProperty -ErrorAction SilentlyContinue -Name "$propertyName" -Path "Registry::$propertyPath" | Select-Object -ExpandProperty "$propertyName"   
    #         if ($null -eq $registryValue) {
    #             continue
    #         }
    #         if (Test-FileExistence (Split-Path -parent $registryValue) $Module.RequiredFiles) {
    #             return (Split-Path -parent $registryValue)
    #         }
    #     }
    #     catch {
    #         continue
    #     }
    # }

    # # Search the folder paths
    # foreach($path in ($Module.CustomFolderPaths + $Module.DefaultFolderPaths)) {
    #     if (Test-FileExistence $path $Module.RequiredFiles) {
    #         return $path
    #     }
    # }

    return $null
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
    
        $arrSet = Get-ConcreteEnvironmentModules
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
        $_ = Import-RequiredModulesRecursive -FullName $Name -LoadedDirectly $True
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
    True if the module was loaded correctly, otherwise false.
    #>
    Write-Verbose "Importing the module $Name recursive"
    
    $moduleInfos = Split-EnvironmentModuleName $FullName
    $name = $moduleInfos[0]
    
    if($script:loadedEnvironmentModules.ContainsKey($name)) {
        $module = $script:loadedEnvironmentModules.Get_Item($name)
        Write-Verbose "The module $name has loaded directly state $($module.IsLoadedDirectly) and should be loaded with state $LoadedDirectly"
        if($module.IsLoadedDirectly -and $LoadedDirectly) {
            return $true
        }
        Write-Verbose "The module $name is already loaded. Increasing reference counter"
        $module.IsLoadedDirectly = $True
        $module.ReferenceCounter++
        return $true
    }

    # Load the dependencies first
    $module = New-EnvironmentModuleInfo -Name $FullName

    if ($null -eq $module) {
        Write-Error "Unable to read environment module description file of module $FullName"
        return $false
    }

    $loadDependenciesDirectly = $false

    if($module.DirectUnload -eq $true) {
        $loadDependenciesDirectly = $LoadedDirectly
    }

    # Identify the root directory
    $moduleRoot = Find-RootDirectory $module

    if (($module.RequiredFiles.Length -gt 0) -and ($null -eq $moduleRoot)) {
        Write-Error "Unable to find the root directory of module $($module.FullName) - Is the program corretly installed?"
        return $false
    }

    Write-Verbose "Children are loaded with directly state $loadDependenciesDirectly"
    foreach ($dependency in $module.RequiredEnvironmentModules) {
        Write-Verbose "Importing dependency $dependency"
        if (-not (Import-RequiredModulesRecursive $dependency $loadDependenciesDirectly)) {
            return $false
        }
    }    

    Write-Verbose "The module has direct unload state $($module.DirectUnload)"
    if($module.DirectUnload -eq $true) {
        [void] (New-Event -SourceIdentifier "EnvironmentModuleLoaded" -EventArguments $module, $LoadedDirectly)   
        return $true
    }

    # Load the module itself
    $module = New-Object "EnvironmentModules.EnvironmentModule" -ArgumentList ($module, $moduleRoot, $LoadedDirectly)
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
        return $false
    }

    [void] (New-Event -SourceIdentifier "EnvironmentModuleLoaded" -EventArguments $module, $LoadedDirectly)   
    return $true
}

function Mount-EnvironmentModuleInternal([EnvironmentModules.EnvironmentModule] $Module)
{
    <#
    .SYNOPSIS
    Deploy all the aliases, environment variables and functions that are stored in the given module object to the environment.
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

        foreach ($function in $Module.Functions.Keys) {
            $value = $Module.Functions[$function]
            Add-EnvironmentModuleFunction $function $Module.FullName $value

            new-item -path function:\ -name "global:$function" -value $value -Force
        }
        
        Write-Verbose ("Register environment module with name " + $Module.Name + " and object " + $Module)
        
        Write-Verbose "Adding module $($Module.Name) to mapping"
        $script:loadedEnvironmentModules[$Module.Name] = $Module

        Write-Host ((Get-EnvironmentModuleDetailedString $Module) + " loaded") -foregroundcolor "Yellow"
        return $true
    }
}