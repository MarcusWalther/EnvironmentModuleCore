$nameRegex = "^[0-9A-Za-z_]+$"
$versionRegex = "^v?(?:(?:(?<epoch>[0-9]+)!)?(?<release>[0-9]*(?:[_\.][0-9]+)*)(?<pre>[_\.]?(?<pre_l>(a|b|c|rc|alpha|beta|pre|preview|sp))[_\.]?(?<pre_n>[0-9]+)?)?(?<post>(?:-(?<post_n1>[0-9]+))|(?:[_\.]?(?<post_l>post|rev|r)[_\.]?(?<post_n2>[0-9]+)?))?(?<dev>[_\.]?(?<dev_l>dev)[_\.]?(?<dev_n>[0-9]+)?)?)(?:\+(?<local>[a-z0-9]+(?:[_\.][a-z0-9]+)*))?$"
$architectureRegex = "^x64|x86$"
$additionalOptionsRegex = "^[0-9A-Za-z.]+$"

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
    .PARAMETER Silent
    Print a warning in case the module name is not correctly formatted.
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

function Get-EnvironmentModuleDescriptionFile([string] $ModuleBase, [string] $ModuleFullName)
{
    <#
    .SYNOPSIS
    Get the Environment Module file (*.pse) of the of the given module.
    .DESCRIPTION
    This function will read the environment module info of the given module. If the module does not depend on the environment module, $null is returned. If no
    description file was found, an empty map is returned.
    .OUTPUTS
    The path to the description file.
    #>

    return (Join-Path $ModuleBase "$($ModuleFullName).pse1")
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

    $descriptionContent = Read-EnvironmentModuleDescriptionFileByPath (Get-EnvironmentModuleDescriptionFile $Module.ModuleBase $Module.Name)

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

function New-EnvironmentModuleInfoFromDescriptionFile([string] $Path, [EnvironmentModuleCore.EnvironmentModuleInfoBase] $Module = $null)
{
    <#
    .SYNOPSIS
    Read the content of the description file stored in the given path and create an EnvironmentModuleInfo object out of it.
    .PARAMETER Path
    The path to the pse1 file to use.
    .PARAMETER Module
    The module info belonging to the pse1 file.
    .OUTPUTS
    The created EnvironmentModuleInfo object or null if the content could not be read.
    #>
    $descriptionContent = Read-EnvironmentModuleDescriptionFileByPath $Path

    if(-not $descriptionContent) {
        return $null
    }

    $result = $null
    $moduleFullName = $Path
    if($null -ne $Module) {
        $arguments = @($Module, $null, (Join-Path $script:tmpEnvironmentRootSessionPath $Module.Name))
        $result = New-Object EnvironmentModuleCore.EnvironmentModuleInfo -ArgumentList $arguments
        $moduleFullName = $Module.FullName
    }
    else {
        $result = New-Object EnvironmentModuleCore.EnvironmentModuleInfo
    }
    Set-EnvironmentModuleInfoBaseParameter $result $descriptionContent

    $result.DirectUnload = $false
    $customSearchPaths = $script:customSearchPaths[$moduleFullName]
    if ($customSearchPaths) {
        $result.SearchPaths = $result.SearchPaths + $customSearchPaths
    }

    $dependencies = @()
    if($descriptionContent.Contains("RequiredEnvironmentModules")) {
        Write-Warning "The field 'RequiredEnvironmentModules' defined for '$moduleFullName' is deprecated, please use the dependencies field."
        $dependencies = $descriptionContent.Item("RequiredEnvironmentModules") | Foreach-Object { New-Object "EnvironmentModuleCore.DependencyInfo" -ArgumentList $_}
        Write-Verbose "Read module dependencies $($dependencies)"
    }

    if($descriptionContent.Contains("Dependencies")) {
        $dependencies = $dependencies + ($descriptionContent.Item("Dependencies") | Foreach-Object {
            if($_.GetType() -eq [string]) {
                New-Object "EnvironmentModuleCore.DependencyInfo" -ArgumentList $_
            }
            else {
                New-Object "EnvironmentModuleCore.DependencyInfo" -ArgumentList $_.Name, $_.Optional
            }
        })
        Write-Verbose "Read module dependencies $($dependencies)"
    }

    $result.Dependencies = $dependencies

    if($descriptionContent.Contains("DirectUnload")) {
        $result.DirectUnload = $descriptionContent.Item("DirectUnload")
        Write-Verbose "Read module direct unload $($result.DirectUnload)"
    }

    if($descriptionContent.Contains("SwitchDirectoryToModuleRoot")) {
        $result.SwitchDirectoryToModuleRoot = $descriptionContent.Item("SwitchDirectoryToModuleRoot")
        Write-Verbose "Read module switch to directory $($result.SwitchDirectoryToModuleRoot)"
    }

    $requiredItems = @()
    if($descriptionContent.Contains("RequiredFiles")) {
        Write-Warning "The field 'RequiredFiles' defined for '$moduleFullName' is deprecated, please use the RequiredItems field."
        $requiredItems = $result.RequiredItems + ($descriptionContent.Item("RequiredFiles") | ForEach-Object {
            New-Object "EnvironmentModuleCore.RequiredItem" -ArgumentList ([EnvironmentModuleCore.RequiredItem]::TYPE_FILE), $_
        })
        Write-Verbose "Read required files $($descriptionContent.Item('RequiredFiles'))"
    }

    if($descriptionContent.Contains("RequiredItems") -and $descriptionContent.Item("RequiredItems").count -gt 0) {
        $requiredItems = $requiredItems + ($descriptionContent.Item("RequiredItems") | Foreach-Object {
            if($_.GetType() -eq [string]) {
                New-Object "EnvironmentModuleCore.RequiredItem" -ArgumentList ([EnvironmentModuleCore.RequiredItem]::TYPE_FILE), $_
            }
            else {
                New-Object "EnvironmentModuleCore.RequiredItem" -ArgumentList $_.Type, $_.Value
            }
        })
        Write-Verbose "Read module dependencies $($dependencies)"
    }

    $result.RequiredItems = $requiredItems

    if($descriptionContent.Contains("DefaultRegistryPaths") -and $descriptionContent.Item("DefaultRegistryPaths").count -gt 0) {
        Write-Warning "The field 'DefaultRegistryPaths' defined for '$moduleFullName' is deprecated, please use the DefaultSearchPaths field."
        $pathValues = $descriptionContent.Item("DefaultRegistryPaths")
        $searchPathType = "REGISTRY"
        $searchPathPriority = $script:searchPathTypes[$searchPathType].Item2
        Write-Verbose "Read default registry paths $($result.DefaultRegistryPaths)"

        $result.SearchPaths = $result.SearchPaths + ($pathValues | ForEach-Object {
            $parts = $_.Split([IO.Path]::PathSeparator) + @("")
            New-Object "EnvironmentModuleCore.SearchPath" -ArgumentList @($parts[0], $searchPathType, $searchPathPriority, $parts[1], $true)
        })
    }

    if($descriptionContent.Contains("DefaultFolderPaths") -and $descriptionContent.Item("DefaultFolderPaths").count -gt 0) {
        Write-Warning "The field 'DefaultFolderPaths' defined for '$moduleFullName' is deprecated, please use the DefaultSearchPaths field."
        $pathValues = $descriptionContent.Item("DefaultFolderPaths")
        $searchPathType = [EnvironmentModuleCore.SearchPath]::TYPE_DIRECTORY
        $searchPathPriority = $script:searchPathTypes[$searchPathType].Item2
        Write-Verbose "Read default folder paths $($result.DefaultFolderPaths)"

        $result.SearchPaths = $result.SearchPaths + ($pathValues | ForEach-Object {
            $parts = $_.Split([IO.Path]::PathSeparator) + @("")
            New-Object "EnvironmentModuleCore.SearchPath" -ArgumentList @($parts[0], $searchPathType, $searchPathPriority, $parts[1], $true)
        })
    }

    if($descriptionContent.Contains("DefaultEnvironmentPaths") -and $descriptionContent.Item("DefaultEnvironmentPaths").count -gt 0) {
        Write-Warning "The field 'DefaultEnvironmentPaths' defined for '$moduleFullName' is deprecated, please use the DefaultSearchPaths field."
        $pathValues = $descriptionContent.Item("DefaultEnvironmentPaths")
        $searchPathType = [EnvironmentModuleCore.SearchPath]::TYPE_ENVIRONMENT_VARIABLE
        $searchPathPriority = $script:searchPathTypes[$searchPathType].Item2
        Write-Verbose "Read default environment paths $($result.DefaultEnvironmentPaths)"

        $result.SearchPaths = $result.SearchPaths + ($pathValues | ForEach-Object {
            $parts = $_.Split([IO.Path]::PathSeparator) + @("")
            New-Object "EnvironmentModuleCore.SearchPath" -ArgumentList @($parts[0], $searchPathType, $searchPathPriority, $parts[1], $true)
        })
    }

    if($descriptionContent.Contains("DefaultSearchPaths") -and $descriptionContent.Item("DefaultSearchPaths").count -gt 0) {
        $result.SearchPaths = $result.SearchPaths + ($descriptionContent.Item("DefaultSearchPaths") | ForEach-Object {
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
        })
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
        $parameters = $descriptionContent.Item("Parameters")
        if($parameters -is [array]) {
            # Handle the complex syntax
            $parameters | Foreach-Object {
                $virtualEnvironment = $_.VirtualEnvironment
                if([string]::IsNullOrEmpty($virtualEnvironment)) {
                    $virtualEnvironment = "Default"
                }
                $parameterKey = [System.Tuple[string, string]]::new($_.Name, $virtualEnvironment)
                $result.Parameters[$parameterKey] = (New-Object "EnvironmentModuleCore.ParameterInfoBase" -ArgumentList $_.Name, $_.Value, $_.IsUserDefined, $virtualEnvironment) 
            }
        }
        else {
            # Handle the simple syntax
            $parameters.Keys | Foreach-Object { 
                $virtualEnvironment = "Default"
                $parameterKey = [System.Tuple[string, string]]::new($_, $virtualEnvironment)
                $result.Parameters[$parameterKey] = (New-Object "EnvironmentModuleCore.ParameterInfoBase" -ArgumentList $_, $parameters[$_], $false, $virtualEnvironment)
            }
        }
        Write-Verbose "Read module parameters $($result.Parameters.GetEnumerator() -join ',')"
    }

    if($descriptionContent.Contains("Paths")) {
        $descriptionContent.Item("Paths") | Foreach-Object {
            $mode = [EnvironmentModuleCore.PathType]::UNKNOWN
            [Enum]::TryParse($_.Mode, [ref] $mode) | Out-Null

            if([String]::IsNullOrEmpty($_.Variable)) {
                Write-Error "Path definition without 'Variable' defined in module definition '$moduleFullName'"
                return
            }

            $pathInfo = $null
            $pathDefinition = $_
            $value = Expand-PathSeparators $pathDefinition.Value
            switch ($mode) {
                APPEND {
                    $pathInfo = $result.AddAppendPath($pathDefinition.Variable, $value, $pathDefinition.Key)
                }
                PREPEND {
                    $pathInfo = $result.AddPrependPath($pathDefinition.Variable, $value, $pathDefinition.Key)
                }
                SET {
                    $pathInfo = $result.AddSetPath($pathDefinition.Variable, $value, $pathDefinition.Key)
                }
                Default {
                    Write-Error "Unable to handle of Mode of static path definition of module '$moduleFullName'"
                    return
                }
            }

            Write-Verbose "Added path definition: $($pathInfo.ToString())"
        }
    }

    if($descriptionContent.Contains("MergeModules")) {
        $result.MergeModules = $descriptionContent.Item("MergeModules")
        Write-Verbose "Read merge modules $($descriptionContent.Item('MergeModules'))"
    }

    if($descriptionContent.Contains("VersionSpecifier")) {
        $versionSpecifier = @()
        $descriptionContent.Item("VersionSpecifier") | Foreach-Object {
            $versionSpecifier += New-Object "EnvironmentModuleCore.VersionInfo" -ArgumentList @($_.Type, $_.File, $_.Value)
        }

        $result.VersionSpecifier = $versionSpecifier
    }

    return $result
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
    .PARAMETER ModuleFile
    The module file (psd1) to load. If this is set, the ModuleFullName is not evaluated.
    .OUTPUTS
    The created object of type EnvironmentModuleInfo or $null.
    .NOTES
    The given module name must match exactly one module, otherwise $null is returned.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param (
        [EnvironmentModuleCore.EnvironmentModuleInfoBase] $Module = $null,
        [String] $ModuleFullName = $null,
        [String] $ModuleFile = $null
    )

    if($null -eq $Module) {
        if(-not ([string]::IsNullOrEmpty($ModuleFile))) {
            $matchingModules = (Get-Module "$ModuleFile" -ListAvailable)

            if($matchingModules.Length -lt 1) {
                Write-Verbose "Unable to find the module $ModuleFile"
                return $null
            }

            $Module = New-EnvironmentModuleInfoBase $matchingModules[0]
        }
        else {
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
    }

    $result = New-EnvironmentModuleInfoFromDescriptionFile -Path (Get-EnvironmentModuleDescriptionFile $Module.ModuleBase $Module.FullName) -Module $Module
    return $result
}

function Compare-EnvironmentModulesByVersion([EnvironmentModuleCore.EnvironmentModuleInfoBase[]] $EnvironmentModules) {
    <#
    .SYNOPSIS
    Compare the given environment modules by its version. If the version is equal, the architecture is compared.
    .PARAMETER EnvironmentModules
    The environment modules to compare.
    .OUTPUTS
    The sorted environment modules.
    #>
    if($null -eq $EnvironmentModules)
    {
        return $null
    }

    $versionMatches = [System.Collections.Generic.Dictionary[String, System.Text.RegularExpressions.Match]]::new()
    foreach($environmentModule in $EnvironmentModules) {
        if([String]::IsNullOrEmpty($environmentModule.Version)) {
            $versionMatches.Add($environmentModule.FullName, $null)
            continue
        }
        $versionMatch = [System.Text.RegularExpressions.Regex]::Match($environmentModule.Version, $versionRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if($versionMatch.Success) {
            $versionMatches.Add($environmentModule.FullName, $versionMatch)
            continue
        }

        $versionMatches.Add($environmentModule.FullName, $null)
    }
    
    $moduleList = [System.Collections.Generic.List[EnvironmentModuleCore.EnvironmentModuleInfoBase]]::new($EnvironmentModules)

    class EnvironmentModuleComparator : System.Collections.Generic.IComparer[EnvironmentModuleCore.EnvironmentModuleInfoBase]
    {
        [System.Collections.Generic.Dictionary[String, System.Text.RegularExpressions.Match]] $versionMatches

        EnvironmentModuleComparator([System.Collections.Generic.Dictionary[String, System.Text.RegularExpressions.Match]] $versionMatches)
        {
            $this.versionMatches = $versionMatches
        }

        [bool] ContainsText([string[]] $versionParts) {
            foreach($part in $versionParts) {
                $tmp = 0
                if(-not([int]::TryParse($part, [ref] $tmp))) {
                    return $true;
                }
            }
            return $false;
        }

        [int] Compare([EnvironmentModuleCore.EnvironmentModuleInfoBase] $a, [EnvironmentModuleCore.EnvironmentModuleInfoBase] $b)
        {
            $matchA = $this.versionMatches[$a.FullName]
            $matchB = $this.versionMatches[$b.FullName]
            if($null -eq $matchA) {
                if($null -eq $matchB) {
                    return $a.Architecture.CompareTo($b.Architecture)
                }
                return 1
            }
    
            if($null -eq $matchB){
                return -1
            }

            $versionPartsA = $matchA.Groups[0].Value.Replace("_", ".").Split(".")
            $versionPartsB = $matchB.Groups[0].Value.Replace("_", ".").Split(".")

            # Check if the version numbers contain text like "dev" or "alpha"
            $containsTextA = $this.ContainsText($versionPartsA)
            $containsTextB = $this.ContainsText($versionPartsB)

            if($containsTextA -and (-not $containsTextB)) {
                return 1
            }

            if($containsTextB -and (-not $containsTextA)) {
                return -1
            }
            
            for($i = 0; $i -lt $versionPartsA.Length; $i++) {
                # the Version A has more parts than B -> A wins
                if($i -gt ($versionPartsB.Length - 1)) {
                    return -1
                }

                $partA = $versionPartsA[$i]
                $partB = $versionPartsB[$i]
                $partANumber = 0
                $partBNumber = 0

                try {
                    [int]::TryParse($partA, [ref] $partANumber) | Out-Null   
                }
                catch {
                }

                try {
                    [int]::TryParse($partB, [ref] $partBNumber) | Out-Null   
                }
                catch {
                }

                if($partANumber -gt $partBNumber) {
                    return -1
                }

                if($partBNumber -gt $partANumber) {
                    return 1
                }
            }

            if($versionPartsB.Length -gt $versionPartsA.Length) {
                # The Version B has more parts than A -> B wins
                return 1
            }

            return $a.Architecture.CompareTo($b.Architecture)
        }
    }

    $comparator = [EnvironmentModuleComparator]::new($versionMatches)
    $moduleList.Sort($comparator);
    return $moduleList
}