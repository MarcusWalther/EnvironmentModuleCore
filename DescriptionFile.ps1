
$nameRegex = "^[0-9A-Za-z_]+$"
$versionRegex = "^v?(?:(?:(?<epoch>[0-9]+)!)?(?<release>[0-9]*(?:[_\.][0-9]+)*)(?<pre>[_\.]?(?<pre_l>(a|b|c|rc|alpha|beta|pre|preview|sp))[_\.]?(?<pre_n>[0-9]+)?)?(?<post>(?:-(?<post_n1>[0-9]+))|(?:[_\.]?(?<post_l>post|rev|r)[_\.]?(?<post_n2>[0-9]+)?))?(?<dev>[_\.]?(?<dev_l>dev)[_\.]?(?<dev_n>[0-9]+)?)?)(?:\+(?<local>[a-z0-9]+(?:[_\.][a-z0-9]+)*))?$"
$architectureRegex = "^x64|x86$"
$additionalOptionsRegex = "^[0-9A-Za-z]+$"

function Split-EnvironmentModuleName([String] $ModuleFullName, [switch] $Silent)
{
    <#
    .SYNOPSIS
    Splits the given name into an array with 4 parts (name, version, architecture, additionalOptions).
    .DESCRIPTION
    Split a name string that either has the format 'Name-Version-Architecture' or just 'Name'. The output is
    an anonymous object with the 4 properties (name, version, architecture, additionalOptions). If a value was not specified,
    $null is returned at the according array index.
    .PARAMETER ModuleFullName
    The full name of the module that should be splitted.
    .OUTPUTS
    A string array with 4 parts (name, version, architecture, additionalOptions)
    #>
    $parts = $ModuleFullName.Split("-")
    $nameMatchResult = [System.Text.RegularExpressions.Regex]::Match($parts[0], $nameRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $result = @{}
    $result.Name = $nameMatchResult.Value

    $regexOrder = @(@($versionRegex, "Version"), @($architectureRegex, "Architecture"), @($additionalOptionsRegex, "AdditionalOptions"))

    $currentRegexIndex = 0
    $matchFailed = (-not ($nameMatchResult.Success))
    for($i = 1; $i -lt $parts.Count; $i++) {
        if($currentRegexIndex -ge $regexOrder.Count) {
            # More parts than matching regexes found
            $matchFailed = $true
            break
        }

        $currentRegex = $regexOrder[$currentRegexIndex][0]
        $matchResult = [System.Text.RegularExpressions.Regex]::Match($parts[$i], $currentRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if($matchResult.Success) {
            $result.($regexOrder[$currentRegexIndex][1]) = $matchResult.Value
        }
        else {
            $i-- # We have to check the same part again with the next regex in the list
        }
        $currentRegexIndex++
    }

    if($matchFailed) {
        if(-not ($Silent)) {
            Write-Warning "The environment module name '$ModuleFullName' is not correctly formated. It must be 'Name-Version-Architecture-AdditionalOptions'"
        }
        return $null
    }

    return $result
}

function Read-EnvironmentModuleDescriptionFile([string] $ModuleBase, [string] $ModuleFullName)
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

    # Search for a pse1 file in the base directory
    return Read-EnvironmentModuleDescriptionFileByPath (Join-Path $ModuleBase "$($ModuleFullName).pse1")
}

function Read-EnvironmentModuleDescriptionFileByPath([string] $Path)
{
    <#
    .SYNOPSIS
    Read the given Environment Module file (*.pse).
    .DESCRIPTION
    This function will read the environment module info. If the description file was not found, an empty map is returned.
    .OUTPUTS
    The map containing the values or $null.
    #>

    if(Test-Path $Path) {
        # Parse the pse1 file
        Write-Verbose "Found desciption file $descriptionFile"
        $descriptionFileContent = Get-Content $Path -Raw
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
    $nameParts = Split-EnvironmentModuleName $Module.Name
    if($null -eq $nameParts) {
        return $null
    }

    $descriptionContent = Read-EnvironmentModuleDescriptionFile $Module.ModuleBase $Module.Name

    if(-not $descriptionContent) {
        return $null
    }

    $result = New-Object EnvironmentModules.EnvironmentModuleInfoBase -ArgumentList @($Module.Name, $Module.ModuleBase, $nameParts.Name, $nameParts.Version, $nameParts.Architecture, $nameParts.AdditionalOptions, [EnvironmentModules.EnvironmentModuleType]::Default)
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

function New-EnvironmentModuleInfo([EnvironmentModules.EnvironmentModuleInfoBase] $Module, [String] $ModuleFullName)
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
        $matchingModules = Get-EnvironmentModule -ListAvailable $ModuleFullName

        if($matchingModules.Length -lt 1) {
            Write-Verbose "Unable to find the module $ModuleFullName in the list of all environment modules"
            return $null
        }

        if($matchingModules.Length -gt 1) {
            Write-Warning "More than one environment module matches the given full name '$ModuleFullName'"
        }

        $Module = $matchingModules[0]
    }

    $descriptionContent = Read-EnvironmentModuleDescriptionFile $Module.ModuleBase $Module.FullName

    if(-not $descriptionContent) {
        return $null
    }

    $arguments = @($Module, $null, (Join-Path $script:tmpEnvironmentRootSessionPath $Module.Name))

    $result = New-Object EnvironmentModules.EnvironmentModuleInfo -ArgumentList $arguments

    Set-EnvironmentModuleInfoBaseParameter $result $descriptionContent

    $result.DirectUnload = $false
    $customSearchPaths = $script:customSearchPaths[$Module.FullName]
    if ($customSearchPaths) {
        $result.SearchPaths = $result.SearchPaths + $customSearchPaths
    }

    $dependencies = @()
    if($descriptionContent.Contains("RequiredEnvironmentModules")) {
        Write-Warning "The field 'RequiredEnvironmentModules' defined for '$($Module.FullName)' is deprecated, please use the dependencies field."
        $dependencies = $descriptionContent.Item("RequiredEnvironmentModules") | Foreach-Object { New-Object "EnvironmentModules.DependencyInfo" -ArgumentList $_}
        Write-Verbose "Read module dependencies $($dependencies)"
    }

    if($descriptionContent.Contains("Dependencies")) {
        $dependencies = $dependencies + $descriptionContent.Item("Dependencies") | Foreach-Object {
            if($_.GetType() -eq [string]) {
                New-Object "EnvironmentModules.DependencyInfo" -ArgumentList $_
            }
            else {
                New-Object "EnvironmentModules.DependencyInfo" -ArgumentList $_.Name, $_.Optional
            }
        }
        Write-Verbose "Read module dependencies $($dependencies)"
    }

    $result.Dependencies = $dependencies

    if($descriptionContent.Contains("DirectUnload")) {
        $result.DirectUnload = $descriptionContent.Item("DirectUnload")
        Write-Verbose "Read module direct unload $($result.DirectUnload)"
    }

    if($descriptionContent.Contains("RequiredFiles")) {
        Write-Warning "The field 'RequiredFiles' defined for '$($Module.FullName)' is deprecated, please use the RequiredItems field."
        $result.RequiredItems = $result.RequiredItems + ($descriptionContent.Item("RequiredFiles") | ForEach-Object {New-Object "EnvironmentModules.EnvironmentModuleRequiredItem" [EnvironmentModules.EnvironmentModuleRequiredItem]::FILE_TYPE $_})
        Write-Verbose "Read required files $($descriptionContent.Item('RequiredFiles'))"
    }

    if($descriptionContent.Contains("DefaultRegistryPaths")) {
        $pathValues = $descriptionContent.Item("DefaultRegistryPaths")

        $result.SearchPaths = $result.SearchPaths + (($pathValues | ForEach-Object {
            $parts = $_.Split([IO.Path]::PathSeparator) + @("")
            New-Object EnvironmentModules.RegistrySearchPath -ArgumentList @($parts[0], $parts[1], $true)
        }))
        Write-Verbose "Read default registry paths $($result.DefaultRegistryPaths)"
    }

    if($descriptionContent.Contains("DefaultFolderPaths")) {
        $pathValues = $descriptionContent.Item("DefaultFolderPaths")
        $result.SearchPaths = $result.SearchPaths + (($pathValues | ForEach-Object {
            $parts = $_.Split([IO.Path]::PathSeparator) + @("")
            New-Object EnvironmentModules.DirectorySearchPath -ArgumentList @($parts[0], $parts[1], $true)
        }))
        Write-Verbose "Read default folder paths $($result.DefaultFolderPaths)"
    }

    if($descriptionContent.Contains("DefaultEnvironmentPaths")) {
        $pathValues = $descriptionContent.Item("DefaultEnvironmentPaths")
        $result.SearchPaths = $result.SearchPaths + (($pathValues | ForEach-Object {
            $parts = $_.Split([IO.Path]::PathSeparator) + @("")
            New-Object EnvironmentModules.EnvironmentSearchPath -ArgumentList @($parts[0], $parts[1], $true)
        }))
        Write-Verbose "Read default environment paths $($result.DefaultEnvironmentPaths)"
    }

    if($descriptionContent.Contains("StyleVersion")) {
        $result.StyleVersion = $descriptionContent.Item("StyleVersion")
        Write-Verbose "Read module style version $($result.StyleVersion)"
    }

    if($descriptionContent.Contains("Category")) {
        $result.Category = $descriptionContent.Item("Category")
        Write-Verbose "Read module category $($result.Category)"
    }

    if($descriptionContent.Contains("Parameters")) {
        $descriptionContent.Item("Parameters").Keys | Foreach-Object { $result.Parameters[$_] = $descriptionContent.Item("Parameters")[$_] }
        Write-Verbose "Read module parameters $($result.Parameters)"
    }

    return $result
}