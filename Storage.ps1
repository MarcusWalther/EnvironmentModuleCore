$script:moduleCacheFileLocation = [IO.Path]::Combine($script:tmpEnvironmentRootPath, "ModuleCache.xml")
$script:searchPathsFileLocation = [IO.Path]::Combine($script:tmpEnvironmentRootPath, "CustomSearchPaths.xml")

function Initialize-EnvironmentModuleCache()
{
    <#
    .SYNOPSIS
    Load the environment modules cache file.
    .DESCRIPTION
    This function will load all environment modules that part of the cache file and will provide them in the environemtModules list.
    .OUTPUTS
    No output is returned.
    #>
    $script:environmentModules = @()
    if(-not (test-path $moduleCacheFileLocation))
    {
        return
    }
    
    $script:environmentModules = Import-CliXml -Path $moduleCacheFileLocation
}

function Initialize-CustomSearchPaths()
{
    <#
    .SYNOPSIS
    Load the custom search paths file.
    .DESCRIPTION
    This function will load all environment modules that part of the cache file and will provide them in the environemtModules list.
    .OUTPUTS
    No output is returned.
    #>
    $script:customSearchPaths = @{}
    $script:customSearchPaths = Import-CliXml -Path $searchPathsFileLocation
}

function Update-EnvironmentModuleCache()
{
    <#
    .SYNOPSIS
    Search for all modules that depend on the environment module and add them to the cache file.
    .DESCRIPTION
    This function will clear the cache file and later iterate over all modules of the system. If the module depends on the environment module, 
    it is added to the cache file.
    .OUTPUTS
    No output is returned.
    #>
    $script:environmentModules = @()
    $modulesByArchitecture = @{}
    $modulesByVersion = @{}
    $allModuleNames = New-Object 'System.Collections.Generic.HashSet[String]'
    
    # Delete all temporary modules created previously
    Remove-Item $tmpEnvironmentModulePath\* -Force -Recurse    
    
    foreach ($module in (Get-Module -ListAvailable)) {
        Write-Verbose "Module $($module.Name) depends on $($module.RequiredModules)"
        $isEnvironmentModule = ("$($module.RequiredModules)" -match "EnvironmentModules")
        if($isEnvironmentModule) {
            Write-Verbose "Environment module $($module.Name) found"
            $script:environmentModules = $script:environmentModules + $module.Name
            $moduleNameParts = Split-EnvironmentModuleName $module.Name
            
            if($moduleNameParts[1] -eq $null) {
              $moduleNameParts[1] = ""
            }
            
            if($moduleNameParts[2] -eq $null) {
              $moduleNameParts[2] = ""
            }
            
            # Add the module to the list of all modules
            $allModuleNames.Add($module.Name) > $null
            
            # Read the environment module properties from the pse1 file
            $description = Read-EnvironmentModuleDescriptionFile $module

            if($description.ModuleType -eq [EnvironmentModules.EnvironmentModuleType]::Meta) {
                continue; #Ignore meta modules
            }
            
            # Handle the module by architecture (if architecture is specified)
            if($moduleNameParts[2] -ne "") {
                $dictionaryKey = [System.Tuple]::Create($moduleNameParts[0],$moduleNameParts[2])
                $dictionaryValue = [System.Tuple]::Create($moduleNameParts[1], $module)
                $oldItem = $modulesByArchitecture.Get_Item($dictionaryKey)
                
                if($oldItem -eq $null) {
                    $modulesByArchitecture.Add($dictionaryKey, $dictionaryValue)
                }
                else {
                    if(($oldItem.Item1) -lt $moduleNameParts[1]) {
                      $modulesByArchitecture.Set_Item($dictionaryKey, $dictionaryValue)
                    }
                }
            }
            
            # Handle the module by version (if version is specified)
            $dictionaryKey = $moduleNameParts[0]
            $dictionaryValue = [System.Tuple]::Create($moduleNameParts[1], $module)
            $oldItem = $modulesByVersion.Get_Item($dictionaryKey)
            
            if($oldItem -eq $null) {
                $modulesByVersion.Add($dictionaryKey, $dictionaryValue)
                continue
            }
            
            if(($oldItem.Item1) -lt $moduleNameParts[1]) {
              $modulesByVersion.Set_Item($dictionaryKey, $dictionaryValue)
            }
        }
    }
 
    foreach($module in $modulesByArchitecture.GetEnumerator()) {
      $moduleName = "$($module.Key.Item1)-$($module.Key.Item2)"
      $defaultModule = $module.Value.Item2
      
      Write-Verbose "Creating module with name $moduleName"

      #Check if there is no module with the default name
      if($allModuleNames.Contains($moduleName)) {
        Write-Verbose "The module $moduleName is not generated, because it does already exist"
        continue
      }
      
      
      [EnvironmentModules.ModuleCreator]::CreateMetaEnvironmentModule($moduleName, $tmpEnvironmentModulePath, $defaultModule, ([IO.Path]::Combine($moduleFileLocation, "..\")), $true, "", $null)
      Write-Verbose "EnvironmentModule $moduleName generated"
      $script:environmentModules = $script:environmentModules + $moduleName
    }
    
    foreach($module in $modulesByVersion.GetEnumerator()) {
      $moduleName = $module.Key
      $defaultModule = $module.Value.Item2
      
      Write-Verbose "Creating module with name $moduleName"

      #Check if there is no module with the default name
      if($allModuleNames.Contains($moduleName)) {
        Write-Verbose "The module $moduleName is not generated, because it does already exist"
        continue
      }
      
      
      [EnvironmentModules.ModuleCreator]::CreateMetaEnvironmentModule($moduleName, $tmpEnvironmentModulePath, $defaultModule, ([IO.Path]::Combine($moduleFileLocation, "..\")), $true, "", $null)
      Write-Verbose "EnvironmentModule $moduleName generated"
      $script:environmentModules = $script:environmentModules + $moduleName
    }    
    
    Write-Host "By Architecture"
    $modulesByArchitecture.GetEnumerator()
    Write-Host "By Version"
    $modulesByVersion.GetEnumerator()

    Export-Clixml -Path "$moduleCacheFileLocation" -InputObject $script:environmentModules
}

function Add-CustomSearchPath
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Directory", "Registry")]
        [string] $Type,
        [Parameter(Mandatory=$true)]
        [string] $Value
    )
    DynamicParam {
        # Set the dynamic parameters' name
        $ParameterName = 'Module'

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
        $Module = $PsBoundParameters[$ParameterName]
    }

    process {   
        $oldSearchPaths = $script:customSearchPaths[$Module]
        $newSearchPath
        if($Type -eq "Directory") {
            $newSearchPath = New-Object EnvironmentModules.DirectorySearchPath -ArgumentList @($false, $Value)
        }
        else {
            $newSearchPath = New-Object EnvironmentModules.RegistrySearchPath -ArgumentList @($false, $Value)
        }

        if($oldSearchPaths) {
            $script:customSearchPaths[$Module] = $oldSearchPaths + @($newSearchPath)
        }
        else {
            $script:customSearchPaths[$Module] = @($newSearchPath)
        }
        Export-Clixml -Path "$script:searchPathsFileLocation" -InputObject $script:customSearchPaths
    }
}

function Clear-CustomSearchPaths
{
    Param(
        [Switch] $Force
    )

    # Ask for deletion
    if(-not $Force) {
        $answer = Read-Host -Prompt "Do you really want to delete all custom seach paths (Y/N)?"

        if($answer.ToLower() -ne "y") {
            return
        }
    }

    $script:customSearchPaths.Clear()
    Export-Clixml -Path "$script:searchPathsFileLocation" -InputObject $script:customSearchPaths
}