
function Split-EnvironmentModuleName([String] $ModuleFullName)
{
    <#
    .SYNOPSIS
    Splits the given name into an array with 4 parts (name, version, architecture, additionalOptions).
    .DESCRIPTION
    Split a name string that either has the format 'Name-Version-Architecture' or just 'Name'. The output is 
    an array with the 4 parts (name, version, architecture, additionalOptions). If a value was not specified, 
    $null is returned at the according array index.
    .PARAMETER ModuleFullName
    The full name of the module that should be splitted.
    .OUTPUTS
    A string array with 4 parts (name, version, architecture, additionalOptions) 
    #>
    $doesMatch = $ModuleFullName -match '^(?<name>[0-9A-Za-z_]+)((-(?<version>([0-9]+(|_[0-9]+)(|_[0-9]+))|(DEF|DEV|NIGHTLY)))|(?<version>))((-(?<architecture>(x64|x86)))|(?<architecture>))((-(?<additionalOptions>[0-9A-Za-z]+))|(?<additionalOptions>))$'
    if($doesMatch) 
    {
        if($matches.version -eq "") {
            $matches.version = $null
        }
        if($matches.architecture -eq "") {
            $matches.architecture = $null
        }
        if($matches.additionalOptions -eq "") {
            $matches.additionalOptions = $null
        }
        
        Write-Verbose "Splitted $Name into parts:"
        Write-Verbose ("Name: " + $matches.name)
        Write-Verbose ("Version: " + $matches.version)
        Write-Verbose ("Architecture: " + $matches.architecture)
        Write-Verbose ("Additional Options: " + $matches.additionalOptions)
        
        return $matches.name, $matches.version, $matches.architecture, $matches.additionalOptions
    }
    else
    {
        Write-Host ("The environment module name " + $Name + " is not correctly formated. It must be 'Name-Version-Architecture-AdditionalOptions'") -ForegroundColor $Host.PrivateData.ErrorForegroundColor -BackgroundColor $Host.PrivateData.ErrorBackgroundColor
        return $null
    }
}

function Read-EnvironmentModuleDescriptionFile([PSModuleInfo] $Module)
{
    <#
    .SYNOPSIS
    Read the Environment Module file (*.pse) of the of the given module.
    .DESCRIPTION
    This function will read the environment module info of the given module. If the module does not depend on the environment module, $null is returned. If no 
    description file was found, an empty map is returned.
    .OUTPUTS
    The map containing the values or $null.
    #>    

    Write-Verbose "Reading environment module description file for $($Module.Name)"
    $isEnvironmentModule = ("$($module.RequiredModules)" -match "EnvironmentModules")

    if(-not $isEnvironmentModule) {
        return $null
    }

    # Search for a pse1 file in the base directory
    $descriptionFile = Join-Path $Module.ModuleBase "$($Module.Name).pse1"

    Write-Verbose "Checking description file $descriptionFile"

    if(Test-Path $descriptionFile) {
        # Parse the pse1 file
        Write-Verbose "Found desciption file $descriptionFile"
        $descriptionFileContent = Get-Content $descriptionFile -Raw
        return Invoke-Expression $descriptionFileContent
    }

    return @{}
}

function New-EnvironmentModuleInfoBase([PSModuleInfo] $Module)
{
    <#
    .SYNOPSIS
    Create a new EnvironmentModuleInfoBase object from the given parameters.
    .PARAMETER Module 
    The module info that contains the base information.
    .OUTPUTS
    The created object of type EnvironmentModuleInfoBase or $null.
    .NOTES
    The given module name must match exactly one module, otherwise $null is returned.
    #>
    $descriptionContent = Read-EnvironmentModuleDescriptionFile $Module

    if(-not $descriptionContent) {
        return $null
    }

    $result = New-Object EnvironmentModules.EnvironmentModuleInfoBase -ArgumentList @($Module.Name)
    Set-EnvironmentModuleInfoBaseParameter $result $descriptionContent

    return $result
}

function Set-EnvironmentModuleInfoBaseParameter([EnvironmentModules.EnvironmentModuleInfoBase][ref] $Module, [hashtable] $Parameters)
{
    <#
    .SYNOPSIS
    Assign the given parameters to the passed module object.
    .PARAMETER Module
    The module to modify.
    .PARAMETER Parameters
    The parameters to set.
    #>
    if($Parameters.Contains("ModuleType")) {
        $Module.ModuleType = [Enum]::Parse([EnvironmentModules.EnvironmentModuleType], $descriptionContent.Item("ModuleType"))
        Write-Verbose "Read module type $($Module.ModuleType)"
    }
}

function New-EnvironmentModuleInfo([PSModuleInfo] $Module, [String] $ModuleFullName)
{
    <#
    .SYNOPSIS
    Create a new EnvironmentModuleInfo object from the given parameters.
    .PARAMETER Module 
    The module info that contains the base information.
    .PARAMETER ModuleFullName
    The full name of the module. Only used if the module parameter is not set.
    .OUTPUTS
    The created object of type EnvironmentModuleInfo or $null.
    .NOTES
    The given module name must match exactly one module, otherwise $null is returned.
    #>  
    if($Module -eq $null) {
        $matchingModules = Get-Module -ListAvailable $ModuleFullName

        if($matchingModules.Length -lt 1) {
            Write-Verbose "Unable to find the module $ModuleFullName in the list of all modules"
            return $null
        }

        if($matchingModules.Length -gt 1) {
            Write-Warning "More than one module matches the given full name '$ModuleFullName'"
        }
        
        $Module = $matchingModules[0]
    }

    $descriptionContent = Read-EnvironmentModuleDescriptionFile $Module

    if(-not $descriptionContent) {
        return $null
    }    

    $arguments = @($Module.Name, (New-Object -TypeName "System.IO.DirectoryInfo" -ArgumentList $Module.ModuleBase)) + (Split-EnvironmentModuleName $Module.Name)

    $result = New-Object EnvironmentModules.EnvironmentModuleInfo -ArgumentList $arguments

    Set-EnvironmentModuleInfoBaseParameter $result $descriptionContent

    $result.DirectUnload = $false
    $customSearchPaths = $script:customSearchPaths[$Module.Name]
    if ($customSearchPaths) {
        $result.SearchPaths = $result.SearchPaths + $customSearchPaths
    }    

    if($descriptionContent.Contains("RequiredEnvironmentModules")) {
        $result.RequiredEnvironmentModules = $descriptionContent.Item("RequiredEnvironmentModules")
        Write-Verbose "Read module dependencies $($result.RequiredEnvironmentModules)"
    }    

    if($descriptionContent.Contains("DirectUnload")) {
        $result.DirectUnload = $descriptionContent.Item("DirectUnload")
        Write-Verbose "Read module direct unload $($result.DirectUnload)"
    }

    if($descriptionContent.Contains("RequiredFiles")) {
        $result.RequiredFiles = $descriptionContent.Item("RequiredFiles")
        Write-Verbose "Read required files $($result.RequiredFiles)"
    }      

    if($descriptionContent.Contains("DefaultRegistryPaths")) {
        $pathValues = $descriptionContent.Item("DefaultRegistryPaths")

        $result.SearchPaths = $result.SearchPaths + (($pathValues | ForEach-Object {
            $parts = $_.Split(";") + @("")
            New-Object EnvironmentModules.RegistrySearchPath -ArgumentList @($parts[0], $parts[1], $true)
        }))
        Write-Verbose "Read default registry paths $($result.DefaultRegistryPaths)"
    }     

    if($descriptionContent.Contains("DefaultFolderPaths")) {
        $pathValues = $descriptionContent.Item("DefaultFolderPaths")
        $result.SearchPaths = $result.SearchPaths + (($pathValues | ForEach-Object {
            $parts = $_.Split(";") + @("")
            New-Object EnvironmentModules.DirectorySearchPath -ArgumentList @($parts[0], $parts[1], $true)
        }))
        Write-Verbose "Read default folder paths $($result.DefaultFolderPaths)"
    }      
    
    if($descriptionContent.Contains("DefaultEnvironmentPaths")) {
        $pathValues = $descriptionContent.Item("DefaultEnvironmentPaths")
        $result.SearchPaths = $result.SearchPaths + (($pathValues | ForEach-Object {
            $parts = $_.Split(";") + @("")
            New-Object EnvironmentModules.EnvironmentSearchPath -ArgumentList @($parts[0], $parts[1], $true)
        }))
        Write-Verbose "Read default environment paths $($result.DefaultEnvironmentPaths)"
    }       

    if($descriptionContent.Contains("StyleVersion")) {
        $result.StyleVersion = $descriptionContent.Item("StyleVersion")
        Write-Verbose "Read module style version $($result.StyleVersion)"
    }         
 
    return $result
}