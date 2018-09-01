
function Split-EnvironmentModuleName([String] $Name)
{
    <#
    .SYNOPSIS
    Splits the given name into an array with 4 parts (name, version, architecture, additionalOptions).
    .DESCRIPTION
    Split a name string that either has the format 'Name-Version-Architecture' or just 'Name'. The output is 
    an array with the 4 parts (name, version, architecture, additionalOptions). If a value was not specified, 
    $null is returned at the according array index.
    .PARAMETER Name
    The name-string that should be splitted.
    .OUTPUTS
    A string array with 4 parts (name, version, architecture, additionalOptions) 
    #>
    $doesMatch = $Name -match '^(?<name>[0-9A-Za-z_]+)((-(?<version>([0-9]+(|_[0-9]+)(|_[0-9]+))|(DEF|DEV|NIGHTLY)))|(?<version>))((-(?<architecture>(x64|x86)))|(?<architecture>))((-(?<additionalOptions>[0-9A-Za-z]+))|(?<additionalOptions>))$'
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
        Write-Host ("The environment module name " + $Name + " is not correctly formated. It must be 'Name-Version-Architecture-AdditionalOptions'") -foregroundcolor "Red"
        return $null
    }
}

function Split-EnvironmentModule([EnvironmentModules.EnvironmentModule] $Module)
{
    <#
    .SYNOPSIS
    Converts the given environment module into an array with 4 parts (name, version, architecture, additionalOptions).
    .DESCRIPTION
    Converts an environment module into an array with 4 parts (name, version, architecture, additionalOptions), to make 
    it comparable to the output of the Split-EnvironmentModuleName function.
    .PARAMETER Module
    The module object that should be transformed.
    .OUTPUTS
    A string array with 4 parts (name, version, architecture, additionalOptions) 
    #>
    return $Module.Name, $Module.Version, $Module.Architecture, $Module.AdditionalOptions
}

function Read-EnvironmentModuleDescriptionFile([PSModuleInfo] $Module, [String] $Name)
{
    <#
    .SYNOPSIS
    Read the PS Module Info of the given module info.
    .DESCRIPTION
    This function will read the environment module info of the given module. If the module does not depend on the environment module, $null is returned.
    .OUTPUTS
    The environment module base info or $null.
    #>    

    if($Module -eq $null) {
        $matchingModules = Get-Module -ListAvailable $Name

        if($matchingModules.Length -eq 0) {
            Write-Verbose "Unable to find the module $Name in the list of all modules"
            return $null
        }
        
        $Module = $matchingModules[0]
    }

    Write-Verbose "Reading environment module description file for $($Module.Name)"
    $isEnvironmentModule = ("$($module.RequiredModules)" -match "EnvironmentModules")

    if(-not $isEnvironmentModule) {
        return $null
    }

    $baseDirectory = $Module.ModuleBase
    $arguments = @($Module.Name, (New-Object -TypeName "System.IO.DirectoryInfo" -ArgumentList $baseDirectory)) + (Split-EnvironmentModuleName $Module.Name)
    $result = New-Object EnvironmentModules.EnvironmentModuleBase -ArgumentList $arguments
    $result.DirectUnload = $false
    $customSearchPaths = $script:customSearchPaths[$Name]
    if ($customSearchPaths) {
        $result.SearchPaths = $result.SearchPaths + $customSearchPaths
    }

    # Search for a pse1 file in the base directory
    $descriptionFile = Join-Path $baseDirectory "$($Module.Name).pse1"

    Write-Verbose "Checking description file $descriptionFile"

    if(Test-Path $descriptionFile) {
        # Parse the pse1 file
        Write-Verbose "Found desciption file $descriptionFile"
        $descriptionFileContent = Get-Content $descriptionFile -Raw
        $descriptionContent = Invoke-Expression $descriptionFileContent

        if($descriptionContent.Contains("ModuleType")) {
            $result.ModuleType = [Enum]::Parse([EnvironmentModules.EnvironmentModuleType], $descriptionContent.Item("ModuleType"))
            Write-Verbose "Read module type $($result.ModuleType)"
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
            $result.SearchPaths = $result.SearchPaths + (($pathValues | ForEach-Object {New-Object EnvironmentModules.RegistrySearchPath -ArgumentList @($true, $_)}))
            Write-Verbose "Read default registry paths $($result.DefaultRegistryPaths)"
        }     
        
        if($descriptionContent.Contains("DefaultFolderPaths")) {
            $pathValues = $descriptionContent.Item("DefaultFolderPaths")
            $result.SearchPaths = $result.SearchPaths + (($pathValues | ForEach-Object {New-Object EnvironmentModules.DirectorySearchPath -ArgumentList @($true, $_)}))
            Write-Verbose "Read default folder paths $($result.DefaultFolderPaths)"
        }         

        if($descriptionContent.Contains("StyleVersion")) {
            $result.StyleVersion = $descriptionContent.Item("StyleVersion")
            Write-Verbose "Read module style version $($result.StyleVersion)"
        }         
    }
 
    return $result
}