function Test-FileExistence([string] $FolderPath, [string[]] $Files, [string] $SubFolderPath) {
    <#
    .SYNOPSIS
    Check if the given folder contains all files given as second parameter.
    .DESCRIPTION
    This function will check if the folder does exist and if it contains all given files.
    .PARAMETER FolderPath
    The folder to check.
    .PARAMETER Files
    The files to check.    
    .PARAMETER SubFolderPath
    The subfolder path that should be appended to the folder path.      
    .OUTPUTS
    True if the folder does exist and if it contains all files, false otherwise.
    #>
    if (-not $FolderPath) {
        Write-Error "No folder path given"
        return $false
    }

    if (-not $SubFolderPath) {
        $SubFolderPath = ""
    }    

    $completePath = Join-Path "$FolderPath" "$SubFolderPath"
    if (-not (Test-Path $completePath)) {
        Write-Verbose "The folder $completePath does not exist"
        return $false
    }

    foreach($file in $Files) {
        if (-not (Test-Path (Join-Path "$completePath" "$file"))) {
            Write-Verbose "The file $file does not exist in folder $completePath"
            return $false
        }
    }

    return $true
}

function Test-EnvironmentModuleRootDirectory([EnvironmentModules.EnvironmentModuleInfo] $Module, [switch] $IncludeDependencies) {
    if(($Module.RequiredFiles.Length -gt 0) -and ($null -eq (Get-EnvironmentModuleRootDirectory $Module))) {
        return $false
    }

    if($IncludeDependencies) {
        foreach ($dependencyModuleName in $Module.RequiredEnvironmentModules) {
            $dependencyModule = Get-EnvironmentModule -ListAvailable $dependencyModuleName

            if(-not $dependencyModule) {
                return $false
            }

            if(-not (Test-EnvironmentModuleRootDirectory $dependencyModule $IncludeDependencies)) {
                return $false
            }
        }
    }

    return $true
}

function Get-EnvironmentModuleRootDirectory([EnvironmentModules.EnvironmentModuleInfo] $Module) {
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
    Write-Verbose "Searching root for $($Module.Name) with $($Module.SearchPaths.Count) search paths and $($Module.RequiredFiles.Count) required files"

    if(($Module.SearchPaths.Count -eq 0) -and ($Module.RequiredFiles.Count -gt 0)) {
        Write-Warning "The module $($Module.FullName) has no defined search paths. Please use the function Add-EnvironmentModuleSearchPath to specify the location"
    }

    foreach($searchPath in $Module.SearchPaths)
    {
        if($searchPath.Type -eq [EnvironmentModules.SearchPathType]::REGISTRY) {
            $pathSegments = $searchPath.Key.Split('\')
            $propertyName = $pathSegments[-1]
            $propertyPath = [string]::Join('\', $pathSegments[0..($pathSegments.Length - 2)])
            
            Write-Verbose "Checking registry search path $($searchPath.Key)"

            try {
                $registryValue = Get-ItemProperty -ErrorAction SilentlyContinue -Name "$propertyName" -Path "Registry::$propertyPath" | Select-Object -ExpandProperty "$propertyName"   
                if ($null -eq $registryValue) {
                    Write-Verbose "Unable to find the registry value $($searchPath.Key)"
                    continue
                }

                Write-Verbose "Found registry value $registryValue"
                $folder = $registryValue
                if(-not [System.IO.Directory]::Exists($folder)) {
                    Write-Verbose "The folder $folder does not exist, using parent"
                    $folder = Split-Path -parent $registryValue
                }

                Write-Verbose "Checking the folder $folder"

                if (Test-FileExistence $folder $Module.RequiredFiles $searchPath.SubFolder) {
                    Write-Verbose "The folder $folder contains the required files"
                    return Join-Path $folder $searchPath.SubFolder
                }
            }
            catch {
                continue
            }

            continue
        }

        if($searchPath.Type -eq [EnvironmentModules.SearchPathType]::Directory) {
            Write-Verbose "Checking directory search path $($searchPath.Key)"
            if (Test-FileExistence $searchPath.Key $Module.RequiredFiles $searchPath.SubFolder) {
                return Join-Path $searchPath.Key $searchPath.SubFolder
            }

            continue
        }

        if($searchPath.Type -eq [EnvironmentModules.SearchPathType]::ENVIRONMENT_VARIABLE) {
            $directory = $([environment]::GetEnvironmentVariable($searchPath.Key))
            Write-Verbose "Checking environment search path $($searchPath.Key) -> $directory"
            if ($directory -and (Test-FileExistence $directory $Module.RequiredFiles $searchPath.SubFolder)) {
                return Join-Path $directory $searchPath.SubFolder
            }

            continue
        }
    }

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
        $_ = Import-RequiredModulesRecursive -ModuleFullName $Name -LoadedDirectly $True
    }
}

function Import-RequiredModulesRecursive([String] $ModuleFullName, [Bool] $LoadedDirectly)
{
    <#
    .SYNOPSIS
    Import the environment module with the given name and all required environment modules.
    .DESCRIPTION
    This function will import the environment module into the scope of the console and will later iterate over all required modules to import them as well.
    .PARAMETER ModuleFullName
    The full name of the environment module to import.
    .OUTPUTS
    True if the module was loaded correctly, otherwise false.
    #>
    Write-Verbose "Importing the module $Name recursive"
    
    $moduleInfos = Split-EnvironmentModuleName $ModuleFullName
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
    $module = New-EnvironmentModuleInfo -ModuleFullName $ModuleFullName

    if ($null -eq $module) {
        Write-Error "Unable to read environment module description file of module $ModuleFullName"
        return $false
    }

    $loadDependenciesDirectly = $false

    if($module.DirectUnload -eq $true) {
        $loadDependenciesDirectly = $LoadedDirectly
    }

    # Identify the root directory
    $moduleRoot = Get-EnvironmentModuleRootDirectory $module

    if (($module.RequiredFiles.Length -gt 0) -and ($null -eq $moduleRoot)) {
        Write-Host "Unable to find the root directory of module $($module.FullName) - Is the program corretly installed?" -ForegroundColor $Host.PrivateData.ErrorForegroundColor -BackgroundColor $Host.PrivateData.ErrorBackgroundColor
        Write-Host "Use 'Add-EnvironmentModuleSearchPath' to specify the location." -ForegroundColor $Host.PrivateData.ErrorForegroundColor -BackgroundColor $Host.PrivateData.ErrorBackgroundColor
        return $false
    }

    Write-Verbose "Children are loaded with directly state $loadDependenciesDirectly"
    foreach ($dependency in $module.RequiredEnvironmentModules) {
        Write-Verbose "Importing dependency $dependency"
        if (-not (Import-RequiredModulesRecursive $dependency $loadDependenciesDirectly)) {
            return $false
        }
    }

    # Load the module itself
    $module = New-Object "EnvironmentModules.EnvironmentModule" -ArgumentList ($module, $moduleRoot, $LoadedDirectly)
    Write-Verbose "Importing the module $ModuleFullName into the Powershell environment"
    Import-Module $ModuleFullName -Scope Global -Force -ArgumentList $module

    Write-Verbose "The module has direct unload state $($module.DirectUnload)"
    if($Module.DirectUnload -eq $false) {
        Mount-EnvironmentModuleInternal $module
        Write-Verbose "Importing of module $ModuleFullName done"
        
        $isLoaded = Test-IsEnvironmentModuleLoaded $ModuleFullName
        
        if(!$isLoaded) {
            Write-Error "The module $ModuleFullName was not loaded successfully"
            $script:silentUnload = $true
            Remove-Module $ModuleFullName -Force
            $script:silentUnload = $false
            return $false
        }
    }
    else {
        [void] (New-Event -SourceIdentifier "EnvironmentModuleLoaded" -EventArguments $module, $LoadedDirectly)   
        Remove-Module $ModuleFullName -Force
        return $true
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
                Write-Host ("The Environment-Module '$($Module.FullName)' is already loaded.") -ForegroundColor $Host.PrivateData.ErrorForegroundColor -BackgroundColor $Host.PrivateData.ErrorBackgroundColor
                return $false
            }
            else {
                Write-Host ("The module '$($Module.FullName)' conflicts with the already loaded module '$($loadedEnvironmentModules.Get_Item($Module.Name).FullName)'") -ForeGroundcolor $Host.PrivateData.ErrorForegroundColor -BackgroundColor $Host.PrivateData.ErrorBackgroundColor
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

        Write-Host ("$($Module.FullName) loaded") -ForegroundColor $Host.PrivateData.DebugForegroundColor -BackgroundColor $Host.PrivateData.DebugBackgroundColor
        return $true
    }
}

function Switch-EnvironmentModule
{   
    <#
    .SYNOPSIS
    Switch a already loaded environment module with a different one.
    .DESCRIPTION
    This function will unmount the giben enivronment module and will load the new one instead.
    .PARAMETER ModuleFullName
    The name of the environment module to unload.
    .PARAMETER NewModuleFullName
    The name of the new environment module to load.
    .OUTPUTS
    No output is returned.
    #>
    [CmdletBinding()]
    Param(
    )
    DynamicParam {
        $runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        $moduleSet = $script:loadedEnvironmentModules.Values | Select-Object -ExpandProperty FullName
        Add-DynamicParameter 'ModuleFullName' String $runtimeParameterDictionary -Mandatory $True -Position 0 -ValidateSet $moduleSet

        $moduleSet = Get-AllEnvironmentModules | Select-Object -ExpandProperty FullName | Where-Object {(Test-IsEnvironmentModuleLoaded $_) -eq $false}
        Add-DynamicParameter 'NewModuleFullName' String $runtimeParameterDictionary -Mandatory $True -Position 1 -ValidateSet $moduleSet
        return $runtimeParameterDictionary
    }
    
    begin {
        # Bind the parameter to a friendly variable
        $moduleFullName = $PsBoundParameters['ModuleFullName']
        $newModuleFullName = $PsBoundParameters['NewModuleFullName']
    }

    process {
        $module = Get-EnvironmentModule($moduleFullName)
        
        if (!$module) {
            Write-Error ("No loaded environment module named $moduleFullName")
            return
        }

        Remove-EnvironmentModule $moduleFullName -Force
        
        Import-EnvironmentModule $newModuleFullName

        [void] (New-Event -SourceIdentifier "EnvironmentModuleSwitched" -EventArguments $moduleFullName, $newModuleFullName)
    }
}

function Add-EnvironmentVariableValue([String] $Variable, [String] $Value, [Bool] $Append = $true)
{
    <#
    .SYNOPSIS
    Add the given value to the desired environment variable.
    .DESCRIPTION
    This function will append or prepend the new value to the environment variable with the given name.
    .PARAMETER Variable
    The name of the environment variable that should be extended.
    .PARAMETER Value
    The new value that should be added to the environment variable.
    .PARAMETER Append
    Set this value to $true if the new value should be appended to the environment variable. Otherwise the value is prepended. 
    .OUTPUTS
    No output is returned.
    #>
    $tmpValue = [environment]::GetEnvironmentVariable($Variable,"Process")
    if(!$tmpValue)
    {
        $tmpValue = $Value
    }
    else
    {
        if($Append) {
            $tmpValue = "${tmpValue};${Value}"
        }
        else {
            $tmpValue = "${Value};${tmpValue}"
        }
    }
    [Environment]::SetEnvironmentVariable($Variable, $tmpValue, "Process")
}

function Add-EnvironmentModuleAlias([String] $Name, [String] $Module, [String] $Definition)
{
    <#
    .SYNOPSIS
    Add a new alias to the active environment.
    .DESCRIPTION
    This function will extend the active environment with a new alias definition. The alias is added to the loaded aliases collection.
    .PARAMETER Name
    The name of the alias.
    .PARAMETER Module
    The module that has defined the alias.
    .PARAMETER Definition
    The alias definition.
    .OUTPUTS
    No output is returned.
    #>    
    $newTupleValue = [System.Tuple]::Create($Definition, $Module)
    # Check if the alias was already used
    if($script:loadedEnvironmentModuleAliases.ContainsKey($Name))
    {
        $knownAliases = $script:loadedEnvironmentModuleAliases[$Name]
        $knownAliases.Add($newTupleValue)
    }
    else {
        $newValue = New-Object "System.Collections.Generic.List[System.Tuple[String, String]]"
        $newValue.Add($newTupleValue)
        $script:loadedEnvironmentModuleAliases.Add($Name, $newValue)
    }
}

function Add-EnvironmentModuleFunction([String] $Name, [String] $Module, [System.Management.Automation.ScriptBlock] $Definition)
{
    <#
    .SYNOPSIS
    Add a new function to the active environment.
    .DESCRIPTION
    This function will extend the active environment with a new function definition. The function is added to the loaded functions stack.
    .PARAMETER Name
    The name of the function.
    .PARAMETER Module
    The module that has defined the function.
    .PARAMETER Definition
    The function definition.
    .OUTPUTS
    No output is returned.
    #>  
    Write-Verbose $Module.ToString()
    $newTupleValue = [System.Tuple]::Create($Definition, $Module)
    # Check if the function was already used
    if($script:loadedEnvironmentModuleFunctions.ContainsKey($Name))
    {
        $knownFunctions = $script:loadedEnvironmentModuleFunctions[$Name]
        $knownFunctions.Add($newTupleValue)
    }
    else {
        $newValue = New-Object "System.Collections.Generic.List[System.Tuple[System.Management.Automation.ScriptBlock, String]]"
        $newValue.Add($newTupleValue)
        $script:loadedEnvironmentModuleFunctions.Add($Name, $newValue)
    }
}