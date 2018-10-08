function Test-IsPartOfTmpDirectory([string] $Destination)
{
    <#
    .SYNOPSIS
    Check if the given folder is part of the configured temp folder for environment modules.
    .PARAMETER Destination
    The folder to check.
    .OUTPUTS
    True if the folder is part of the temporary directory.
    #>    
    $tmpDirectory = New-Object -TypeName "System.IO.DirectoryInfo" ($script:tmpEnvironmentRootPath)

    if($Destination.StartsWith($tmpDirectory.FullName)) {
        Write-Error "The target destination is part of the temporary directory. Please specify another directory or set the force parameter."
        return $true
    }

    return $false
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

        if($null -eq $selectedPath) {
            return
        }

        if((-not $Force) -and (Test-IsPartOfTmpDirectory $selectedPath)) {
            return
        }        

        [EnvironmentModules.ModuleCreator]::CreateEnvironmentModule($Name, $selectedPath, $Description, $environmentModulePath, $Author, $Version, $Architecture, $Executable, $AdditionalEnvironmentModules)
        Update-EnvironmentModuleCache
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
        if($matchingModules.Length -lt 1) {
            Write-Error "Unable to find module matching name '$ModuleName'"
            return
        }
        if($matchingModules.Length -gt 1) {
            Write-Warning "Found multiple modules matching the name '$ModuleName'"
        }
        
        $moduleFolder = ($matchingModules[0]).ModuleBase
        $destination = Resolve-Path(Join-Path $moduleFolder '..\')
        
        if($Path) {
            $destination = $Path
        }
        else {
            $selectedPath = Select-ModulePath          

            if($null -eq $selectedPath) {
                return
            }

            $destination = $selectedPath
        }

        $destination = Join-Path $destination $NewName

        if((-not $Force) -and (Test-IsPartOfTmpDirectory $selectedPath)) {
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
                    $fileContent = $fileContent -replace "GUID[ ]*=[ ]*'[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}'", "GUID = '$newId'"
                }
                Default {}
            }

            ($fileContent.Replace("$ModuleName", "$NewName")) > "$newFullName"
        }
        
        Update-EnvironmentModuleCache
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

function Select-ModulePath
{
    <#
    .SYNOPSIS
    Show a selection dialog for module paths.
    .DESCRIPTION
    This function will an input selection for all module paths that are defined.
    .OUTPUTS
    The selected module path or $null if no path was selected.
    #>
    $pathPossibilities = $env:PSModulePath.Split(";") | Where-Object {Test-Path $_} | Select-Object -Unique {Resolve-Path $_}
    return Show-SelectDialogue $pathPossibilities "Select the target directory for the module"
}