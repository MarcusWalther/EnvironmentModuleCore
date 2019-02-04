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

    Write-Verbose "Testing file exisiting '$Files' in folder '$Folder' and subfolder '$SubFolderPath'"

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

function Test-EnvironmentModuleRootDirectory([EnvironmentModules.EnvironmentModuleInfo] $Module, [switch] $IncludeDependencies)
{
    <#
    .SYNOPSIS
    Check if the given module has a valid root directory (containing all required files).
    .DESCRIPTION
    This function will check all defined root directory seach paths of the given module. If at least one of these directories contains all required files, $true is returned.
    .PARAMETER Module
    The module to handle.
    .PARAMETER IncludeDependencies
    Set this value to $true, if all dependencies should be checked as well. The result is only $true, if the module and all dependencies have a valid root directory.
    .OUTPUTS
    True if a valid root directory was found.
    #>
    if(($Module.RequiredFiles.Length -gt 0) -and ($null -eq (Get-EnvironmentModuleRootDirectory $Module))) {
        return $false
    }

    if($IncludeDependencies) {
        foreach ($dependency in $Module.Dependencies) {
            $dependencyModule = Get-EnvironmentModule -ListAvailable $dependency.ModuleFullName

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

function Get-EnvironmentModuleRootDirectory([EnvironmentModules.EnvironmentModuleInfo] $Module)
{
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
            $propertyName = Split-Path -Leaf $searchPath.Key
            $propertyPath = Split-Path $searchPath.Key

            Write-Verbose "Checking registry search path $($searchPath.Key)"
            Write-Verbose "Splitted registry search path into path '$propertyPath' and name '$propertyName'"

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
    .PARAMETER ModuleFullName
    The full name of the environment module.
    .PARAMETER IsLoadedDirectly
    True if the load was triggered by the user. False if triggered by another module. Default: $true
    .PARAMETER Silent
    Do not print output to the console.
    .OUTPUTS
    No outputs are returned.
    #>
    [CmdletBinding()]
    Param(
        [switch] $Silent
    )
    DynamicParam {
        $runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $moduleSet = Get-ConcreteEnvironmentModules -ListAvailable | Select-Object -ExpandProperty "FullName"
        Add-DynamicParameter 'ModuleFullName' String $runtimeParameterDictionary -Mandatory $true -Position 0 -ValidateSet $moduleSet
        Add-DynamicParameter 'IsLoadedDirectly' Bool $runtimeParameterDictionary -Mandatory $false -Position 1 -ValidateSet @($true, $false)
        return $runtimeParameterDictionary
    }

    begin {
        # Bind the parameter to a friendly variable
        $ModuleFullName = $PsBoundParameters["ModuleFullName"]
        $IsLoadedDirectly = $PsBoundParameters["IsLoadedDirectly"]
    }

    process {
        $silentMode = $false
        if($silent) {
            $silentMode = $true
        }

        if($null -eq $IsLoadedDirectly) {
            $IsLoadedDirectly = $true
        }

        $initialSilentLoadState = $script:silentLoad
        $_ = Import-RequiredModulesRecursive $ModuleFullName $IsLoadedDirectly (New-Object "System.Collections.Generic.HashSet[string]") $silentMode
        $script:silentLoad = $initialSilentLoadState
    }
}

function Import-RequiredModulesRecursive([String] $ModuleFullName, [Bool] $LoadedDirectly, [System.Collections.Generic.HashSet[string]][ref] $KnownModules, [Bool] $SilentMode)
{
    <#
    .SYNOPSIS
    Import the environment module with the given name and all required environment modules.
    .DESCRIPTION
    This function will import the environment module into the scope of the console and will later iterate over all required modules to import them as well.
    .PARAMETER ModuleFullName
    The full name of the environment module to import.
    .PARAMETER LoadedDirectly
    True if the module was loaded directly by the user. False if it was loaded as dependency.
    .PARAMETER KnownModules
    A collection of known modules, used to detect circular dependencies.
    .PARAMETER SilentMode
    True if no outputs should be printed.
    .OUTPUTS
    True if the module was loaded correctly, otherwise false.
    #>
    $progressName = "$($Module.FullName) Loading"
    Write-Progress -activity $progressName -status "Analysing name $($Module.FullName)" -percentcomplete 10

    if($KnownModules.Contains($ModuleFullName) -and (0 -eq (Get-Module $ModuleFullName).Count)) {
        Write-Error "A circular dependency between the modules was detected"
        return $false
    }
    $_ = $KnownModules.Add($ModuleFullName)

    Write-Verbose "Importing the module $ModuleFullName recursive"

    $conflictTestResult = (Test-ConflictsWithLoadedModules $ModuleFullName)
    $module = $conflictTestResult.Module
    $conflict = $conflictTestResult.Conflict

    if($conflict) {
        if(-not ($SilentMode)) {
            Write-Error ("The module '$ModuleFullName' conflicts with the already loaded module '$($module.FullName)'")
        }
        return $false
    }

    if($null -ne $module) {
        Write-Verbose "The module $ModuleFullName has loaded directly state $($module.IsLoadedDirectly) and should be loaded with state $LoadedDirectly"
        if($module.IsLoadedDirectly -and $LoadedDirectly) {
            return $true
        }
        Write-Verbose "The module $ModuleFullName is already loaded. Increasing reference counter"
        $module.IsLoadedDirectly = $True
        $module.ReferenceCounter++
        return $true
    }

    # Load the dependencies first
    Write-Progress -activity $progressName -status "Loading module info" -percentcomplete 20
    $module = New-EnvironmentModuleInfo -ModuleFullName $ModuleFullName

    $alreadyLoadedModules = $null
    if(($module.ModuleType -eq [EnvironmentModules.EnvironmentModuleType]::Meta) -and ($LoadedDirectly)) {
        $script:silentLoad = $true
        $alreadyLoadedModules = Get-EnvironmentModule
    }

    if ($null -eq $module) {
        if(-not($SilentMode)) {
            Write-Error "Unable to read environment module description file of module $ModuleFullName"
        }
        return $false
    }

    $loadDependenciesDirectly = $false

    if($module.DirectUnload -eq $true) {
        $loadDependenciesDirectly = $LoadedDirectly
    }

    # Identify the root directory
    $moduleRoot = Get-EnvironmentModuleRootDirectory $module

    if (($module.RequiredFiles.Length -gt 0) -and ($null -eq $moduleRoot)) {
        if(-not $SilentMode) {
            Write-Host "Unable to find the root directory of module $($module.FullName) - Is the program corretly installed?" -ForegroundColor $Host.PrivateData.ErrorForegroundColor -BackgroundColor $Host.PrivateData.ErrorBackgroundColor
            Write-Host "Use 'Add-EnvironmentModuleSearchPath' to specify the location." -ForegroundColor $Host.PrivateData.ErrorForegroundColor -BackgroundColor $Host.PrivateData.ErrorBackgroundColor
        }
        return $false
    }

    Write-Verbose "Children are loaded with directly state $loadDependenciesDirectly"
    $loadedDependencies = New-Object "System.Collections.Stack"
    Write-Progress -activity $progressName -status "Importing dependencies" -percentcomplete 30

    if($module.Dependencies.Count -gt 0) {
        $percentagePerDependency = 50 / $module.Dependencies.Count
        $dependencyIndex = 0
        foreach ($dependency in $module.Dependencies) {
            $percentageComplete = 30 + ($percentagePerDependency * $dependencyIndex)
            Write-Progress -activity $progressName -status "Importing dependency $dependency" -percentcomplete $percentageComplete
            Write-Verbose "Importing dependency $dependency"
            $loadingResult = (Import-RequiredModulesRecursive $dependency.ModuleFullName $loadDependenciesDirectly $KnownModules)
            if (-not $loadingResult) {
                while ($loadedDependencies.Count -gt 0) {
                    Remove-EnvironmentModule ($loadedDependencies.Pop())
                }
                return $false
            }
            else {
                $loadedDependencies.Push($dependency.ModuleFullName)
            }

            $dependencyIndex++
        }
    }

    # Create the temp directory
    mkdir -Force $module.TmpDirectory
    Write-Progress -activity $progressName -status "Importing the module itself" -percentcomplete 85

    # Set the parameter defaults
    $module.Parameters.Keys | ForEach-Object { Set-EnvironmentModuleParameterInternal $_ $module.Parameters[$_] $ModuleFullName }

    # Load the module itself
    $module = New-Object "EnvironmentModules.EnvironmentModule" -ArgumentList ($module, $moduleRoot, $LoadedDirectly)
    Write-Verbose "Importing the module $ModuleFullName into the Powershell environment"
    Import-Module $ModuleFullName -Scope Global -Force -ArgumentList $module

    Write-Verbose "The module has direct unload state $($module.DirectUnload)"
    if($Module.DirectUnload -eq $false) {
        $isLoaded = Mount-EnvironmentModuleInternal $module $SilentMode
        Write-Verbose "Importing of module $ModuleFullName done"

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

    Write-Progress -activity $progressName -status "Finishing import" -percentcomplete 95

    # Print the summary
    if(($module.ModuleType -eq [EnvironmentModules.EnvironmentModuleType]::Meta) -and ($LoadedDirectly) -and (-not $SilentMode)) {
        Show-EnvironmentSummary -ModuleBlacklist $alreadyLoadedModules
    }

    [void] (New-Event -SourceIdentifier "EnvironmentModuleLoaded" -EventArguments $module, $LoadedDirectly)
    return $true
}

function Mount-EnvironmentModuleInternal([EnvironmentModules.EnvironmentModule] $Module, [Bool] $SilentMode)
{
    <#
    .SYNOPSIS
    Deploy all the aliases, environment variables and functions that are stored in the given module object to the environment.
    .DESCRIPTION
    This function will export all aliases and environment variables that are defined in the given EnvironmentModule-object.
    .PARAMETER Module
    The module that should be deployed.
    .PARAMETER SilentMode
    True if no outputs should be printed.
    .OUTPUTS
    A boolean value that is $true if the module was loaded successfully. Otherwise the value is $false.
    #>
    process {
        $SilentMode = $SilentMode -or $script:silentLoad
        Write-Verbose "Try to load module '$($Module.Name)' with architecture '$($Module.Architecture)', Version '$($Module.Version)' and type '$($Module.ModuleType)'"

        Write-Verbose "Identified $($Module.Paths.Length) paths"
        foreach ($pathInfo in $Module.Paths)
        {
            [String] $joinedValue = $pathInfo.Values -join [IO.Path]::PathSeparator
            Write-Verbose "Handling path for variable $($pathInfo.Variable) with joined value $joinedValue"
            if($joinedValue -eq "")  {
                continue
            }

            if ($pathInfo.PathType -eq [EnvironmentModules.EnvironmentModulePathType]::PREPEND) {
                Write-Verbose "Joined Prepend-Path: $($pathInfo.Variable) = $joinedValue"
                Add-EnvironmentVariableValue -Variable $pathInfo.Variable -Value $joinedValue -Append $false
            }
            if ($pathInfo.PathType -eq [EnvironmentModules.EnvironmentModulePathType]::APPEND) {
                Write-Verbose "Joined Append-Path: $($pathInfo.Variable) = $joinedValue"
                Add-EnvironmentVariableValue -Variable $pathInfo.Variable -Value $joinedValue -Append $true
            }
            if ($pathInfo.PathType -eq [EnvironmentModules.EnvironmentModulePathType]::SET) {
                Write-Verbose "Joined Set-Path: $($pathInfo.Variable) = $joinedValue"
                [Environment]::SetEnvironmentVariable($pathInfo.Variable, $joinedValue, "Process")
            }
        }

        foreach ($aliasInfo in $Module.Aliases.Values) {
            Add-EnvironmentModuleAlias $aliasInfo

            Set-Alias -name $aliasInfo.Name -value $aliasInfo.Definition -scope "Global"
            if(($aliasInfo.Description -ne "") -and (-not $SilentMode)) {
                if(-not $SilentMode) {
                    Write-Host $aliasInfo.Description -Foregroundcolor $Host.PrivateData.VerboseForegroundColor -BackgroundColor $Host.PrivateData.VerboseBackgroundColor
                }
            }
        }

        foreach ($functionInfo in $Module.Functions.Values) {
            Add-EnvironmentModuleFunction $functionInfo

            new-item -path function:\ -name "global:$($functionInfo.Name)" -value $functionInfo.Definition -Force
        }

        Write-Verbose ("Register environment module with name " + $Module.Name + " and object " + $Module)

        Write-Verbose "Adding module $($Module.Name) to mapping"
        $script:loadedEnvironmentModules[$Module.Name] = $Module

        if($script:configuration["ShowLoadingMessages"]) {
            Write-Host ("$($Module.FullName) loaded")
        }

        return $true
    }
}

function Show-EnvironmentSummary([EnvironmentModules.EnvironmentModuleInfoBase[]] $ModuleBlacklist = $null)
{
    <#
    .SYNOPSIS
    Print a summary of the environment that is currenctly loaded.
    .DESCRIPTION
    This function will print all modules, functions, aliases and parameters of the current environment to the host console.
    .OUTPUTS
    No output is returned.
    #>
    $aliases = Get-EnvironmentModuleAlias | Sort-Object -Property "Name"
    $functions = Get-EnvironmentModuleFunction | Sort-Object -Property "Name"
    $parameters = Get-EnvironmentModuleParameter | Sort-Object -Property "Name"
    $modules = Get-ConcreteEnvironmentModules | Sort-Object -Property "FullName"

    Write-Host ""
    Write-Host "--------------------" -ForegroundColor $Host.PrivateData.WarningForegroundColor -BackgroundColor $Host.PrivateData.WarningBackgroundColor
    Write-Host "Loaded Modules:" -ForegroundColor $Host.PrivateData.WarningForegroundColor -BackgroundColor $Host.PrivateData.WarningBackgroundColor

    $moduleBlackListNames = $ModuleBlacklist | Select-Object -ExpandProperty "FullName"
    $modules | ForEach-Object {
        if(-not ($moduleBlackListNames -match $_.FullName)) {
            Write-Host "  * $($_.FullName)"
        }
    }

    Write-Host "Available Functions:" -ForegroundColor $Host.PrivateData.WarningForegroundColor -BackgroundColor $Host.PrivateData.WarningBackgroundColor
    $functions | ForEach-Object {
        if(-not ($moduleBlackListNames -match $_.ModuleFullName)) {
            Write-Host "  * $($_.Name) - " -NoNewline
            Write-Host $_.ModuleFullName -ForegroundColor $Host.PrivateData.VerboseForegroundColor -BackgroundColor $Host.PrivateData.VerboseBackgroundColor
        }
    }

    Write-Host "Available Aliases:" -ForegroundColor $Host.PrivateData.WarningForegroundColor -BackgroundColor $Host.PrivateData.WarningBackgroundColor
    $aliases | ForEach-Object {
        if(-not ($moduleBlackListNames -match $_.ModuleFullName)) {
            Write-Host "  * $($_.Name) - " -NoNewline
            Write-Host $_.Description -ForegroundColor $Host.PrivateData.VerboseForegroundColor -BackgroundColor $Host.PrivateData.VerboseBackgroundColor
        }
    }

    Write-Host "Available Parameters:" -ForegroundColor $Host.PrivateData.WarningForegroundColor -BackgroundColor $Host.PrivateData.WarningBackgroundColor
    $parameters | ForEach-Object {
        Write-Host "  * $($_.Name) - " -NoNewline
        Write-Host $_.Value -ForegroundColor $Host.PrivateData.VerboseForegroundColor -BackgroundColor $Host.PrivateData.VerboseBackgroundColor
    }
    Write-Host "--------------------" -ForegroundColor $Host.PrivateData.WarningForegroundColor -BackgroundColor $Host.PrivateData.WarningBackgroundColor
    Write-Host ""
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

        $moduleSet = Get-LoadedEnvironmentModules | Select-Object -ExpandProperty FullName
        Add-DynamicParameter 'ModuleFullName' String $runtimeParameterDictionary -Mandatory $True -Position 0 -ValidateSet $moduleSet

        $moduleSet = Get-AllEnvironmentModules | Select-Object -ExpandProperty FullName | Where-Object {(Test-EnvironmentModuleLoaded $_) -eq $false}
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
            $tmpValue = "$tmpValue$([IO.Path]::PathSeparator)$Value"
        }
        else {
            $tmpValue = "$Value$([IO.Path]::PathSeparator)$tmpValue"
        }
    }
    [Environment]::SetEnvironmentVariable($Variable, $tmpValue, "Process")
}

function Add-EnvironmentModuleAlias([EnvironmentModules.EnvironmentModuleAliasInfo] $AliasInfo)
{
    <#
    .SYNOPSIS
    Add a new alias to the active environment.
    .DESCRIPTION
    This function will extend the active environment with a new alias definition. The alias is added to the loaded aliases collection.
    .PARAMETER AliasInfo
    The definition of the alias.
    .OUTPUTS
    No output is returned.
    #>

    # Check if the alias was already used
    if($script:loadedEnvironmentModuleAliases.ContainsKey($AliasInfo.Name))
    {
        $knownAliases = $script:loadedEnvironmentModuleAliases[$AliasInfo.Name]
        $knownAliases.Add($AliasInfo)
    }
    else {
        $newValue = New-Object "System.Collections.Generic.List[EnvironmentModules.EnvironmentModuleAliasInfo]"
        $newValue.Add($AliasInfo)
        $script:loadedEnvironmentModuleAliases.Add($AliasInfo.Name, $newValue)
    }
}

function Add-EnvironmentModuleFunction([EnvironmentModules.EnvironmentModuleFunctionInfo] $FunctionDefinition)
{
    <#
    .SYNOPSIS
    Add a new function to the active environment.
    .DESCRIPTION
    This function will extend the active environment with a new function definition. The function is added to the loaded functions stack.
    .PARAMETER FunctionDefinition
    The definition of the function.
    .OUTPUTS
    No output is returned.
    #>

    # Check if the function was already used
    if($script:loadedEnvironmentModuleFunctions.ContainsKey($FunctionDefinition.Name))
    {
        $knownFunctions = $script:loadedEnvironmentModuleFunctions[$FunctionDefinition.Name]
        $knownFunctions.Add($FunctionDefinition)
    }
    else {
        $newValue = New-Object "System.Collections.Generic.List[EnvironmentModules.EnvironmentModuleFunctionInfo]"
        $newValue.Add($FunctionDefinition)
        $script:loadedEnvironmentModuleFunctions.Add($FunctionDefinition.Name, $newValue)
    }
}

function Test-ConflictsWithLoadedModules([string] $ModuleFullName)
{
    <#
    .SYNOPSIS
    Check if the given module name conflicts with the already loaded modules.
    .DESCRIPTION
    This function will compare the given module name with the list of all loaded modules. If the module conflicts in version or architecture,
    true is returned.
    .PARAMETER ModuleFullName
    The name of the module to check.
    .OUTPUTS
    A tuple containing a boolean value as first argument. True if the module does conflict with the already loaded modules, false otherwise.
    And the identified module as second argument.
    #>
    $moduleNameParts = Split-EnvironmentModuleName $ModuleFullName
    $name = $moduleNameParts.Name
    $version = $moduleNameParts.Version
    $architecture = $moduleNameParts.Architecture

    $module = $null
    $conflict = $false

    if($script:loadedEnvironmentModules.ContainsKey($name)) {
        $module = $script:loadedEnvironmentModules.Get_Item($name)
        Write-Verbose "A module matching name '$name' was already found - checking for version or architecture conflict"

        if(-not ($module.DirectUnload)) {
            if(-not ([string]::IsNullOrEmpty($version))) {
                # A specific version is required
                if([string]::IsNullOrEmpty($module.Version)) {
                    Write-Warning "The already loaded module $($module.FullName) has no version specifier. Don't know if it is compatible to version '$version'"
                }
                else {
                    if($version -ne $module.Version) {
                        $conflict = $true
                    }
                }
            }

            if(-not ([string]::IsNullOrEmpty($architecture))) {
                # A specific architecture is required
                if([string]::IsNullOrEmpty($module.Architecture)) {
                    Write-Warning "The already loaded module $($module.FullName) has no architecture specifier. Don't know if it is compatible to architecture '$architecture'"
                }
                else {
                    if($architecture -ne $module.Architecture) {
                        $conflict = $true
                    }
                }
            }
        }
    }

    $result = @{}
    $result.Conflict = $conflict
    $result.Module = $module

    return $result
}