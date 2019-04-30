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
        return Import-PowershellDataFile $Path
    }

    return @{}
}

function New-EnvironmentModuleInfoBase
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
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param (
        [PSModuleInfo] $Module
    )

    $nameParts = Split-EnvironmentModuleName $Module.Name
    if($null -eq $nameParts) {
        return $null
    }

    $descriptionContent = Read-EnvironmentModuleDescriptionFile $Module.ModuleBase $Module.Name

    if(-not $descriptionContent) {
        return $null
    }

    $result = New-Object EnvironmentModuleCore.EnvironmentModuleInfoBase -ArgumentList @($Module.Name, $Module.ModuleBase, $nameParts.Name, $nameParts.Version, $nameParts.Architecture, $nameParts.AdditionalOptions, [EnvironmentModuleCore.EnvironmentModuleType]::Default)
    Set-EnvironmentModuleInfoBaseParameter $result $descriptionContent

    return $result
}

function Set-EnvironmentModuleInfoBaseParameter
{
    <#
    .SYNOPSIS
    Assign the given parameters to the passed module object.
    .PARAMETER Module
    The module to modify.
    .PARAMETER Parameters
    The parameters to set.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [EnvironmentModuleCore.EnvironmentModuleInfoBase][ref] $Module,
        [hashtable] $Parameters
    )

    if($Parameters.Contains("ModuleType")) {
        $Module.ModuleType = [Enum]::Parse([EnvironmentModuleCore.EnvironmentModuleType], $descriptionContent.Item("ModuleType"))
        Write-Verbose "Read module type $($Module.ModuleType)"
    }
}

function New-EnvironmentModuleInfo
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
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param (
        [EnvironmentModuleCore.EnvironmentModuleInfoBase] $Module,
        [String] $ModuleFullName
    )

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

    $result = New-Object EnvironmentModuleCore.EnvironmentModuleInfo -ArgumentList $arguments

    Set-EnvironmentModuleInfoBaseParameter $result $descriptionContent

    $result.DirectUnload = $false
    $customSearchPaths = $script:customSearchPaths[$Module.FullName]
    if ($customSearchPaths) {
        $result.SearchPaths = $result.SearchPaths + $customSearchPaths
    }

    $dependencies = @()
    if($descriptionContent.Contains("RequiredEnvironmentModules")) {
        Write-Warning "The field 'RequiredEnvironmentModules' defined for '$($Module.FullName)' is deprecated, please use the dependencies field."
        $dependencies = $descriptionContent.Item("RequiredEnvironmentModules") | Foreach-Object { New-Object "EnvironmentModuleCore.DependencyInfo" -ArgumentList $_}
        Write-Verbose "Read module dependencies $($dependencies)"
    }

    if($descriptionContent.Contains("Dependencies")) {
        $dependencies = $dependencies + $descriptionContent.Item("Dependencies") | Foreach-Object {
            if($_.GetType() -eq [string]) {
                New-Object "EnvironmentModuleCore.DependencyInfo" -ArgumentList $_
            }
            else {
                New-Object "EnvironmentModuleCore.DependencyInfo" -ArgumentList $_.Name, $_.Optional
            }
        }
        Write-Verbose "Read module dependencies $($dependencies)"
    }

    $result.Dependencies = $dependencies

    if($descriptionContent.Contains("DirectUnload")) {
        $result.DirectUnload = $descriptionContent.Item("DirectUnload")
        Write-Verbose "Read module direct unload $($result.DirectUnload)"
    }

    $requiredItems = @()
    if($descriptionContent.Contains("RequiredFiles")) {
        Write-Warning "The field 'RequiredFiles' defined for '$($Module.FullName)' is deprecated, please use the RequiredItems field."
        $requiredItems = $result.RequiredItems + ($descriptionContent.Item("RequiredFiles") | ForEach-Object {
            New-Object "EnvironmentModuleCore.RequiredItem" -ArgumentList ([EnvironmentModuleCore.RequiredItem]::TYPE_FILE), $_
        })
        Write-Verbose "Read required files $($descriptionContent.Item('RequiredFiles'))"
    }

    if($descriptionContent.Contains("RequiredItems")) {
        $requiredItems = $requiredItems + $descriptionContent.Item("RequiredItems") | Foreach-Object {
            if($_.GetType() -eq [string]) {
                New-Object "EnvironmentModuleCore.RequiredItem" -ArgumentList ([EnvironmentModuleCore.RequiredItem]::TYPE_FILE), $_
            }
            else {
                New-Object "EnvironmentModuleCore.RequiredItem" -ArgumentList $_.Type, $_.Value
            }
        }
        Write-Verbose "Read module dependencies $($dependencies)"
    }

    $result.RequiredItems = $requiredItems

    if($descriptionContent.Contains("DefaultRegistryPaths")) {
        Write-Warning "The field 'DefaultRegistryPaths' defined for '$($Module.FullName)' is deprecated, please use the DefaultSearchPaths field."
        $pathValues = $descriptionContent.Item("DefaultRegistryPaths")
        $searchPathType = "REGISTRY"
        $searchPathPriority = $script:searchPathTypes[$searchPathType].Item2
        Write-Verbose "Read default registry paths $($result.DefaultRegistryPaths)"

        $result.SearchPaths = $result.SearchPaths + (($pathValues | ForEach-Object {
            $parts = $_.Split([IO.Path]::PathSeparator) + @("")
            New-Object "EnvironmentModuleCore.SearchPath" -ArgumentList @($parts[0], $searchPathType, $searchPathPriority, $parts[1], $true)
        }))
    }

    if($descriptionContent.Contains("DefaultFolderPaths")) {
        Write-Warning "The field 'DefaultFolderPaths' defined for '$($Module.FullName)' is deprecated, please use the DefaultSearchPaths field."
        $pathValues = $descriptionContent.Item("DefaultFolderPaths")
        $searchPathType = [EnvironmentModuleCore.SearchPath]::TYPE_DIRECTORY
        $searchPathPriority = $script:searchPathTypes[$searchPathType].Item2
        Write-Verbose "Read default folder paths $($result.DefaultFolderPaths)"

        $result.SearchPaths = $result.SearchPaths + (($pathValues | ForEach-Object {
            $parts = $_.Split([IO.Path]::PathSeparator) + @("")
            New-Object "EnvironmentModuleCore.SearchPath" -ArgumentList @($parts[0], $searchPathType, $searchPathPriority, $parts[1], $true)
        }))
    }

    if($descriptionContent.Contains("DefaultEnvironmentPaths")) {
        Write-Warning "The field 'DefaultEnvironmentPaths' defined for '$($Module.FullName)' is deprecated, please use the DefaultSearchPaths field."
        $pathValues = $descriptionContent.Item("DefaultEnvironmentPaths")
        $searchPathType = [EnvironmentModuleCore.SearchPath]::TYPE_ENVIRONMENT_VARIABLE
        $searchPathPriority = $script:searchPathTypes[$searchPathType].Item2
        Write-Verbose "Read default environment paths $($result.DefaultEnvironmentPaths)"

        $result.SearchPaths = $result.SearchPaths + (($pathValues | ForEach-Object {
            $parts = $_.Split([IO.Path]::PathSeparator) + @("")
            New-Object "EnvironmentModuleCore.SearchPath" -ArgumentList @($parts[0], $searchPathType, $searchPathPriority, $parts[1], $true)
        }))
    }

    if($descriptionContent.Contains("DefaultSearchPaths")) {
        $result.SearchPaths = $result.SearchPaths + $descriptionContent.Item("DefaultSearchPaths") | Foreach-Object {
            if($_.GetType() -eq [string]) {
                $searchPathType = [EnvironmentModuleCore.SearchPath]::TYPE_DIRECTORY
                $searchPathPriority = $script:searchPathTypes[$searchPathType].Item2
                New-Object "EnvironmentModuleCore.SearchPath" -ArgumentList $_, $searchPathType, $searchPathPriority, $null, $true
            }
            else {
                $searchPathType = $_.Type
                $searchPathPriority = $_.Priority
                if($null -eq $searchPathPriority) {
                    $searchPathPriority = $script:searchPathTypes[$searchPathType].Item2
                }

                New-Object "EnvironmentModuleCore.SearchPath" -ArgumentList $_.Key, $searchPathType, $searchPathPriority, $_.SubFolder, $true
            }
        }
        Write-Verbose "Read module default search paths $($result.SearchPaths)"
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
        Write-Verbose "Read module parameters $($result.Parameters.GetEnumerator() -join ',')"
    }

    return $result
}