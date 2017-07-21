# Depends on the logic of EnvironmentModules.psm1

function Mount-EnvironmentModule([String] $Name, [String] $Root, [String] $Version, [String] $Architecture, [System.Management.Automation.PSModuleInfo] $Info, 
                                 [System.Management.Automation.ScriptBlock] $CreationDelegate, [System.Management.Automation.ScriptBlock] $DeletionDelegate, 
                                 $Dependencies) {
    <#
    .SYNOPSIS
    Creates a new environment module object out of the given parameters. After that, the creationDelegate is called, which can export environment variables or aliases.
    .DESCRIPTION
    Each environment module must be available as 'EnvironmentModules.EnvironmentModule'-object, which holds all information about the exported environment variables and aliases. 
    This function is a factory-function that generates a new 'EnvironmentModules.EnvironmentModule'-object with the given name, program-version 
    and architecture. After the creation is completed, the code given in the creationDelegate is invoked. If the module is removed from the environment, the deletionDelegate
    is invoked.
    .PARAMETER Name
    The name of the environment module. That is usually the same as the powershell module name. 
    .PARAMETER Root
    The root directory of the program which is loaded through the environment module. 
    .PARAMETER Version
    The version of the program that is loaded through the powershell module. This is not be the version of the powershell-module!
    .PARAMETER Architecture
    The architecture of the program that is loaded through the powershell module. This value is unused at the moment.
    .PARAMETER Info
    The powershell module that should be registered. This is usually '$MyInvocation.MyCommand.ScriptBlock.Module'
    .PARAMETER CreationDelegate
    The code that should be executed when the environment module is loaded. The code should take 2 arguments, the generated module that 
    can be filled with further information and the root directory of the module.
    .PARAMETER DeletionDelegate
    The code that should be executed when the environment module is removed. This is just a wrapper for the OnRemove delegate.
    .PARAMETER Dependencies
    All dependencies to other enivronment modules. 
    .OUTPUTS
    A boolean value that indicates if the environment module was successfully created.
    .NOTE
    With the current concept it's impossible to get the description and other information from the module manifest.
    #>
    if($Root) {
        $moduleInfos = Split-EnvironmentModuleName $Name
        
        if(!$moduleInfos) {
            Write-Error ("The name of the enivronment module '" + $Name + "'cannot be split into its parts")
            return $null
        }
        if($Version) {
            $moduleInfos[1] = $Version
        }
        if($Architecture) {
            $moduleInfos[2] = $Architecture
        }
        
        Write-Verbose ("Creating environment module with name '" + $moduleInfos[0] + "', version '" + $moduleInfos[1] + "', architecture '" + $moduleInfos[2] + "', additional information '" + $moduleInfos[3] + "' and dependencies " + $Dependencies)
        [EnvironmentModules.EnvironmentModule] $module = New-Object EnvironmentModules.EnvironmentModule($moduleInfos[0], $moduleInfos[1], $moduleInfos[2], $moduleInfos[3])
        $module = ($CreationDelegate.Invoke($module, $Root))[0]
        $successfull = Mount-EnvironmentModuleInternal($module)
        $Info.OnRemove = $DeletionDelegate    
        
        $module.EnvironmentModuleDependencies = $Dependencies
        return $true
    }
    else {
        Write-Host ($Name + " not found") -foregroundcolor "DarkGray"
    }
    return $false
}

function Compare-EnvironmentModuleInfos([String[]] $Module1, [String[]] $Module2)
{
    <#
    .SYNOPSIS
    Compares two given module information if their name, version and architecture is equal.
    .DESCRIPTION
    Compares two given module information if their name, version and architecture is equal. The additional attributes are ignored at the moment. 
    The module information can be generated with the help of the functions 'Split-EnvironmentModuleName' and 'Split-EnvironmentModule'.
    .PARAMETER Module1
    The first module information that should be compared.
    .PARAMETER Module2
    The second module information that should be compared.
    .OUTPUTS
    $true if the name, version and architecture values are equal. Otherwise $false
    #>
    Write-Verbose ("  - Name equal? " + (Compare-PossibleNullStrings $Module1[0] $Module2[0]))
    Write-Verbose ("  - Version equal? " + (Compare-PossibleNullStrings $Module1[1] $Module2[1]))
    Write-Verbose ("  - Architecture equal? " + (Compare-PossibleNullStrings $Module1[2] $Module2[2]))
    return ((Compare-PossibleNullStrings $Module1[0] $Module2[0]) -and ((Compare-PossibleNullStrings $Module1[1] $Module2[1]) -and (Compare-PossibleNullStrings $Module1[2] $Module2[2])))
}

function Get-EnvironmentModule([String] $Name = $null, [switch] $ListAvailable)
{
    <#
    .SYNOPSIS
    Get the environment module object, loaded by the given module name.
    .DESCRIPTION
    This function will check if an environment module with the given name was loaded and will return it. The 
    name is just the name of the module, without version, architecture or other information.
    .PARAMETER Name
    The module name of the required module object.
    .PARAMETER ListAvailable
    Show all environment modules that are available on the system.
    .OUTPUTS
    The EnvironmentModule-object if a module with the given name was already loaded. If no module with 
    name was found, $null is returned.
    #>
    if($ListAvailable) {
        $script:environmentModules
    }
    
    if([string]::IsNullOrEmpty($Name)) {
        Get-LoadedEnvironmentModules
        return
    }
    
    #$moduleInfos = Split-EnvironmentModuleName $Name
    #if(!$moduleInfos) {
    #   return $null
    #}
    #
    #Write-Verbose ("Try to find environment module with name '" + $Name + "'")
    #foreach ($var in $loadedEnvironmentModules.GetEnumerator()) {
    #   Write-Verbose ("Checking " + (Get-EnvironmentModuleDetailedString $var.Value))
    #   $tmpModuleInfos = Split-EnvironmentModule $var.Value
    #   if(Compare-EnvironmentModuleInfos $moduleInfos $tmpModuleInfos) {
    #       return $var.Value
    #   }
    #}
    
    #return $null
    
    return $loadedEnvironmentModules.Get_Item($Name)
}

function Get-EnvironmentModuleDetailedString([EnvironmentModules.EnvironmentModule] $Module)
{
    <#
    .SYNOPSIS
    This is the reverse function of Split-EnvironmentModuleName. It will convert the information stored in 
    the given EnvironmentModule-object to a String containing Name, Version, Architecture and additional options.
    .DESCRIPTION
    Convert the given EnvironmentModule to a String with the form Name-Version[Architecture]-AdditionalOptions.
    .PARAMETER Module
    The module that should be converted to a String.
    .OUTPUTS
    A string with the form Name-Version[Architecture]-AdditionalOptions.
    #>
    $resultString = $Module.Name
    Write-Verbose "Creating detailed string with name $($Module.Name)"
    if($Module.Version) {
        $resultString += "-" + $Module.Version
        Write-Verbose "Adding version to detailed string with value $($Module.Version)"
    }
    if($Module.Architecture) {
        $resultString += '-' + $Module.Architecture
        Write-Verbose "Adding architecture to detailed string with value $($Module.Architecture)"
    }
    if($Module.AdditionalInfo) {
        $resultString += '-' + $Module.AdditionalInfo
        Write-Verbose "Adding additional information to detailed string with value $($Module.AdditionalInfo)"
    }    
    return $resultString
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
            Set-Alias -name $alias -value $aliasValue.Item1 -scope "Global"
            if($aliasValue.Item2 -ne "") {
                Write-Host $aliasValue.Item2 -foregroundcolor "Green"
            }
        }
        
        Write-Verbose ("Register environment module with name " + $Module.Name + " and object " + $Module)
        
        Write-Verbose "Adding module $($Module.Name) to mapping"
        $loadedEnvironmentModules[$Module.Name] = $Module

        $Module.Load()
        Write-Host ((Get-EnvironmentModuleDetailedString $Module) + " loaded") -foregroundcolor "Yellow"
        return $true
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
        
        $Module.Unload()
        Write-Verbose "Removing module $(Get-EnvironmentModuleDetailedString $Module)"
        Remove-Module (Get-EnvironmentModuleDetailedString $Module) -Force
        if(!$silentUnload) {
            Write-Host ($Module.Name + " unloaded") -foregroundcolor "Yellow"
        }
        return
    }
}

function Get-LoadedEnvironmentModules()
{
    <#
    .SYNOPSIS
    Get all loaded environment module names.
    .DESCRIPTION
    This function will return a String list, containing the names of all loaded environment modules.
    .OUTPUTS
    The String list containing the names of all environment modules.
    #>
    [String[]]$values = $loadedEnvironmentModules.getEnumerator() | % { Get-EnvironmentModuleDetailedString $_.Value }
    return $values
}

function Get-LoadedEnvironmentModulesFullName()
{
    <#
    .SYNOPSIS
    Get all loaded environment modules with full name.
    .DESCRIPTION
    This function will return a String list, containing the names of all loaded environment modules.
    .OUTPUTS
    The String list containing the names of all environment modules.
    #>
    [String[]]$values = $loadedEnvironmentModules.getEnumerator() | % { Get-EnvironmentModuleDetailedString($_.Value) }
    return $values
}

function Test-IsEnvironmentModuleLoaded([String] $Name)
{
    <#
    .SYNOPSIS
    Check if the environment module with the given name is already loaded.
    .DESCRIPTION
    This function will check if Import-Module was called for an enivronment module with the given name.
    .PARAMETER Name
    The name of the module that should be tested.
    .OUTPUTS
    $true if the environment module was already loaded, otherwise $false.
    #>
    $loadedModule = (Get-EnvironmentModule $Name)
    if(!$loadedModule) {
        return $false
    }
        
    return $true
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

function Switch-EnvironmentModule
{   
    <#
    .SYNOPSIS
    Switch a already loaded environment module with a different one.
    .DESCRIPTION
    This function will unmount the giben enivronment module and will load the new one instead.
    .PARAMETER ModuleName
    The name of the environment module to unload.
    .PARAMETER NewModuleName
    The name of the new environment module to load.
    .OUTPUTS
    No output is returned.
    #>
    [CmdletBinding()]
    Param(
        [switch] $Force
    )
    DynamicParam {
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        
        $ModuleNameParameterName = 'ModuleName'
        $ModuleNameAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ModuleNameParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ModuleNameParameterAttribute.Mandatory = $true
        $ModuleNameParameterAttribute.Position = 0
        $ModuleNameAttributeCollection.Add($ModuleNameParameterAttribute)
        $ModuleNameArrSet = Get-LoadedEnvironmentModulesFullName
        $ModuleNameValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($ModuleNameArrSet)
        $ModuleNameAttributeCollection.Add($ModuleNameValidateSetAttribute)
        $ModuleNameRuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ModuleNameParameterName, [string], $ModuleNameAttributeCollection)
        $RuntimeParameterDictionary.Add($ModuleNameParameterName, $ModuleNameRuntimeParameter)

        $NewModuleNameParameterName = 'NewModuleName'       
        $NewModuleNameAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]      
        $NewModuleNameParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $NewModuleNameParameterAttribute.Mandatory = $true
        $NewModuleNameParameterAttribute.Position = 1
        $NewModuleNameAttributeCollection.Add($NewModuleNameParameterAttribute)     
        $NewModuleNameArrSet = $script:environmentModules
        $NewModuleNameValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($NewModuleNameArrSet)     
        $NewModuleNameAttributeCollection.Add($NewModuleNameValidateSetAttribute)
        $NewModuleNameRuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($NewModuleNameParameterName, [string], $NewModuleNameAttributeCollection)
        $RuntimeParameterDictionary.Add($NewModuleNameParameterName, $NewModuleNameRuntimeParameter)
        
        return $RuntimeParameterDictionary
    }
    
    begin {
        # Bind the parameter to a friendly variable
        $moduleName = $PsBoundParameters[$ModuleNameParameterName]
        $newModuleName = $PsBoundParameters[$NewModuleNameParameterName]
    }

    process {
        $module = Get-EnvironmentModule($moduleName)
        
        if (!$module) {
            Write-Error ("No loaded environment module named $moduleName")
            return
        }
        
        $moduleName = Get-EnvironmentModuleDetailedString($module)
        if($Force) {
            Remove-Module $moduleName -Force
        }
        else {
            Remove-Module $moduleName
        }
        
        Import-EnvironmentModule $newModuleName
    }
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
    
        # Generate and set the ValidateSet 
        $arrSet = $script:environmentModules
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
    
    Write-Verbose "Importing the module $FullName into the Powershell environment"
    Import-Module $FullName -Scope Global -Force
    Write-Verbose "Importing of module $FullName done"
    
    $isLoaded = Test-IsEnvironmentModuleLoaded $name
    
    if(!$isLoaded) {
        Write-Error "The module $FullName was not loaded successfully"
        $silentUnload = $true
        Remove-Module $FullName -Force
        $silentUnload = $false
        return
    }
    
    $module = $script:loadedEnvironmentModules.Get_Item($name)
    $loadDependenciesDirectly = $false
    
    Write-Verbose "Checking type of the module $name - it is $($module.ModuleType)"
    if($module.ModuleType -eq [EnvironmentModules.EnvironmentModuleType]::Meta) {
        Write-Verbose "The module is a meta module and hence unloaded"
        $silentUnload = $true
        Dismount-EnvironmentModule $module
        $silentUnload = $false
        $loadDependenciesDirectly = ($true -and $LoadedDirectly)
    }      
    else {
        $module.IsLoadedDirectly = $LoadedDirectly
    }
    
    Write-Verbose "Children are loaded with directly state $loadDependenciesDirectly"
    foreach ($dependency in $module.EnvironmentModuleDependencies) {
        Write-Verbose "Importing dependency $dependency"
        Import-RequiredModulesRecursive $dependency $loadDependenciesDirectly
    }
}

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
        Remove-RequiredModulesRecursive -FullName $Name -UnloadedDirectly $True
    }
}

function Remove-RequiredModulesRecursive([String] $FullName, [Bool] $UnloadedDirectly)
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
    
    if($UnloadedDirectly -and !$module.IsLoadedDirectly) {
        Write-Error "Unable to remove module $Name because it was imported as dependency"
        return;
    }

    $module.ReferenceCounter--
    
    Write-Verbose "The module $($module.Name) has now a reference counter of $($module.ReferenceCounter)"
    
    foreach ($refModule in $module.EnvironmentModuleDependencies) {
        Remove-RequiredModulesRecursive $refModule $False
    }   
    
    if($module.ReferenceCounter -le 0) {
        Write-Verbose "Removing Module $($module.Name)" 
        Dismount-EnvironmentModule $module
    }   
}

function New-EnvironmentModule
{
    <#
    .SYNOPSIS
    Create a new environment module
    .DESCRIPTION
    This function will create a new environment module with the given parameter.
    .PARAMETER Name
    The name of the environment module to generate.
    .PARAMETER Author
    The author of the environment module. If this value is not specified, the system user name is used.
    .PARAMETER Description
    An optional description for the module.
    .OUTPUTS
    No outputs are returned.
    #>
    Param(
        [String] $Name,
        [String] $Author,
        [String] $Description,
        [String] $Version,
        [String] $Architecture,
        [String] $Executable
    )
    
    process {
        if([string]::IsNullOrEmpty($Name)) {
            Write-Error('A module name must be specified')
            return
        }
        if([string]::IsNullOrEmpty($Author)) {
            $Author = [Environment]::UserName
        }
        if([string]::IsNullOrEmpty($Description)) {
            $Description = "Empty Description"
        }       
        if([string]::IsNullOrEmpty($Executable)) {
            Write-Error('An executable must be specified')
            return
        }       
        
        $environmentModulePath = Resolve-Path (Join-Path $moduleFileLocation "..\")
        $moduleRootPath = Resolve-Path (Join-Path $environmentModulePath "..\")
        
        $pathPossibilities = (Split-String -Input $env:PSModulePath -Separator ";")
        Write-Host "Select the target directory for the module:"
        
        $i = 1
        foreach ($path in $pathPossibilities) {
            Write-Host "[$i] $path"
            $i++
        }
        
        $selectedIndex = Read-Host -Prompt ""
        #[EnvironmentModules.ModuleCreator]::CreateEnvironmentModule($Name, $moduleRootPath, $Description, $environmentModulePath, $Author, $Version, $Architecture, $Executable)
        #Update-EnvironmentModuleCache
    }
}

function New-EnvironmentModuleFunction
{
    <#
    .SYNOPSIS
    Export the given function in global scope.
    .DESCRIPTION
    This function will export a module function in global scope. This will prevent the powershell from automtically explore the function if the module is not loaded.
    .PARAMETER Name
    The name of the function to export.
    .PARAMETER Value
    The script block to export.
    .OUTPUTS
    No outputs are returned.
    #>
    Param(
        [String] $Name,
        [System.Management.Automation.ScriptBlock] $Value
    )
    
    process {   
        new-item -path function:\ -name "global:$Name" -value $Value -Force
    }
}

function New-EnvironmentModuleExecuteFunction
{
    <#
    .SYNOPSIS
    Export the given function in global scope.
    .DESCRIPTION
    This function will export a module function in global scope. This will prevent the powershell from automtically explore the function if the module is not loaded.
    .PARAMETER Name
    The name of the function to export.
    .PARAMETER Value
    The script block to export.
    .OUTPUTS
    No outputs are returned.
    #>
    Param(
        [String] $Name,
        [System.Management.Automation.ScriptBlock] $Value
    )
    
    process {   
        new-item -path function:\ -name "global:$Name" -Force -value {
          $Value.invoke($args)
        }
    }  
}

function Edit-EnvironmentModule
{
    <#
    .SYNOPSIS
    Edit the environment module files.
    .DESCRIPTION
    This function will open the environment module files with the default editor.
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
    
        # Generate and set the ValidateSet 
        $arrSet = $script:environmentModules
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
        $modules = Get-Module -ListAvailable $Name
        
        if(($modules -eq $null) -or ($modules.Count -eq 0)) {
            Write-Error "The module was not found"
            return
        }
        
        Get-ChildItem ($modules[0].ModuleBase) | Invoke-Item
    }
}

function Copy-EnvironmentModule
{
    <#
    .SYNOPSIS
    Copy the given environment module under the given name and generate a new GUID.
    .DESCRIPTION
    This function will clone the given module and will specify a new GUID for it. If required, the module search path is adapted.
    .PARAMETER Name
    The module to copy.
    .PARAMETER NewName
    The new name of the module.
    .OUTPUTS
    No outputs are returned.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String] $NewName,
        [String] $Path,
        [Switch] $Force
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
        $arrSet = $script:environmentModules
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
        $ModuleName = $PsBoundParameters[$ParameterName]
    }

    process {
        $matchingModules = (Get-Module -ListAvailable $ModuleName)
        if($matchingModules.Length -ne 1) {
            Write-Error "Found multiple modules matching the name '$ModuleName'"
        }
        
        $moduleFolder = ($matchingModules[0]).ModuleBase
        $destination = Resolve-Path(Join-Path $moduleFolder '..\')
        
        if($Path) {
            $destination = $Path
        }
        
        $destination = New-Object -TypeName "System.IO.DirectoryInfo" (Join-Path $destination $NewName)
        $tmpDirectory = New-Object -TypeName "System.IO.DirectoryInfo" ($script:tmpEnvironmentRootPath)

        $destination.FullName
        $tmpDirectory.FullName

        if(($destination.FullName.StartsWith($tmpDirectory.FullName)) -and (-not $Force)) {
            Write-Error "The target destination is part of the temporary directory. Please specify another directory."
            return
        }

        if((Test-Path $destination) -and (-not $Force)) {
            Write-Error "The folder $destination does already exist"
            return
        }
        
        mkdir $destination -Force
        
        Write-Host "Cloning module $Name to $destination"
        
        $filesToCopy = Get-ChildItem $moduleFolder
        
        Write-Verbose "Found $($filesToCopy.Length) files to copy"

        foreach($file in $filesToCopy) {
            $length = $file.Name.Length - $file.Extension.Length
            $shortName = $file.Name.Substring(0, $length)
            $newFileName = $file.Name

            if("$shortName" -match "$Name") {
                $newFileName = "$($NewName)$($file.Extension)"
            }

            $newFullName = Join-Path $destination $newFileName
            Copy-Item -Path "$($file.FullName)" -Destination "$newFullName"

            Write-Verbose "Handling file with extension $($file.Extension.ToUpper())"
            $fileContent = (Get-Content $newFullName)
            $newId = [Guid]::NewGuid()

            switch ($file.Extension.ToUpper()) {
                ".PSD1" {
                    $fileContent -replace "GUID[ ]*=[ ]*'[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}'",'GUID = $newId'
                }
                Default {}
            }

            ($fileContent.Replace("$ModuleName", "$NewName")) > "$newFullName"
        }
        
        Update-EnvironmentModuleCache
    }
}