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

function Get-EnvironmentModule([String] $Name = "*", [switch] $ListAvailable, [string] $Architecture = "*", [string] $Version = "*")
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
        foreach($module in Get-AllEnvironmentModules) {
            if(-not ($module.FullName -like $Name)) {
                continue
            }

            if(($null -ne $module.Architecture) -and (-not ($module.Architecture -like $Architecture))) {
                continue
            }

            if(($null -ne $module.Version) -and (-not ($module.Version -like $Version))) {
                continue
            }            

            $result = New-EnvironmentModuleInfo -Name $module.FullName     
            $result
        }
    }
    else {
        $filteredResult = $loadedEnvironmentModules.GetEnumerator() | Where-Object {$_.Value.FullName -like $Name} | Select-Object -ExpandProperty "Value"
        $filteredResult = $filteredResult | Where-Object {(($null -eq $_.Version) -or ($_.Version -like $Version)) -and (($null -eq $_.Architecture) -or ($_.Architecture -like $Architecture))}

        return $filteredResult
    }
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
    return $script:loadedEnvironmentModules.getEnumerator() | % { $_.Value }
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
        [String] $Executable,
        [String[]] $AdditionalEnvironmentModules,
        [Switch] $Force
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
            $Description = ""
        }       
        if([string]::IsNullOrEmpty($Executable)) {
            Write-Error('An executable must be specified')
            return
        }       
        
        $environmentModulePath = Resolve-Path (Join-Path $moduleFileLocation "..\")

        $selectedPath = Select-ModulePath

        if($selectedPath -eq $null) {
            return
        }

        Check-IsPartOfTmpDirectory $selectedPath $Force

        [EnvironmentModules.ModuleCreator]::CreateEnvironmentModule($Name, $selectedPath, $Description, $environmentModulePath, $Author, $Version, $Architecture, $Executable, $AdditionalEnvironmentModules)
        Update-EnvironmentModuleCache
    }
}

function Select-ModulePath
{
    $pathPossibilities = $env:PSModulePath.Split(";")
    Write-Host "Select the target directory for the module:"
    $indexPathMap = @{}

    $i = 1
    foreach ($path in $pathPossibilities) {
        if(-not (Test-Path $path)) {
            continue
        }
        $path = $(Resolve-Path $path)
        Write-Host "[$i] $path"
        $indexPathMap[$i] = $path
        $i++
    }
        
    $selectedIndex = Read-Host -Prompt " "
    Write-Verbose "Got selected index $selectedIndex and path possibilities $($pathPossibilities.Count)"
    if(-not($selectedIndex -match '^[0-9]+$')) {
        Write-Error "Invalid index specified"
        return $null
    }

    $selectedIndex = [int]($selectedIndex)
    if(($selectedIndex -lt 1) -or ($selectedIndex -gt $pathPossibilities.Count)) {
        Write-Error "Invalid index specified"
        return $null
    }

    Write-Verbose "The selected path is $($indexPathMap[$selectedIndex])"
    Write-Verbose "Calculated selected index $selectedIndex - for possibilities $pathPossibilities"

    return $indexPathMap[$selectedIndex]
}

function Check-IsPartOfTmpDirectory([string] $Destination, [bool] $Force)
{
    $tmpDirectory = New-Object -TypeName "System.IO.DirectoryInfo" ($script:tmpEnvironmentRootPath)

    if(($Destination.StartsWith($tmpDirectory.FullName)) -and (-not $Force)) {
        Write-Error "The target destination is part of the temporary directory. Please specify another directory or set the force parameter."
        return $true
    }

    return $false
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
    .PARAMETER ModuleName
    The name of the module exporting the function.    
    .OUTPUTS
    No outputs are returned.
    #>
    Param(
        [Parameter(Mandatory=$true)]
        [String] $Name,
        [Parameter(Mandatory=$true)]
        [String] $ModuleName,
        [Parameter(Mandatory=$true)] 
        [System.Management.Automation.ScriptBlock] $Value 
    )
    
    process {   
        Write-Verbose "Registering environment module function $Name with value $Value and module name $ModuleName"
        if([System.String]::IsNullOrEmpty($ModuleName)) {
            Write-Error "No module name for the environment module function $Name given"
            return
        }
        
        Add-EnvironmentModuleFunction $Name $ModuleName $Value

        new-item -path function:\ -name "global:$Name" -value $Value -Force
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
        [String] $FileFilter = '*.*'
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
        $arrSet = Get-AllEnvironmentModules | Select-Object -ExpandProperty "FullName"
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
        
        if(($null -eq $modules) -or ($modules.Count -eq 0)) {
            Write-Error "The module was not found"
            return
        }
        
        Get-ChildItem ($modules[0].ModuleBase) | Where-Object {$_ -like $FileFilter} | Invoke-Item
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
        $arrSet = Get-AllEnvironmentModules | Select-Object -ExpandProperty "FullName"
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
        else {
            $selectedPath = Select-ModulePath          

            if($selectedPath -eq $null) {
                return
            }

            $destination = $selectedPath
        }

        $destination = Join-Path $destination $NewName

        Check-IsPartOfTmpDirectory $selectedPath $Force

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
                    $fileContent = $fileContent -replace "GUID[ ]*=[ ]*'[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}'", "GUID = '$newId'"
                }
                Default {}
            }

            ($fileContent.Replace("$ModuleName", "$NewName")) > "$newFullName"
        }
        
        Update-EnvironmentModuleCache
    }
}