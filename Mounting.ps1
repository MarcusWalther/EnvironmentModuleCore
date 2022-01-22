# ---------------------------------
# Search Path Extension Point
# ---------------------------------

$script:searchPathTypes = @{}

function Register-EnvironmentModuleSearchPathType([string] $Type, [int] $DefaultPriority, [scriptblock] $Handler)
{
    $script:searchPathTypes[$Type] = New-Object "System.Tuple[scriptblock, int]" -ArgumentList $Handler, $DefaultPriority
}

Register-EnvironmentModuleSearchPathType ([EnvironmentModuleCore.SearchPath]::TYPE_DIRECTORY) 8 {
    param([EnvironmentModuleCore.SearchPath] $SearchPath, [EnvironmentModuleCore.EnvironmentModuleInfo] $Module)
    Write-Verbose "Checking directory search path $($SearchPath.Key)"

    if([string]::IsNullOrEmpty($SearchPath.Key)) {
        Write-Warning "Directory search path without key specified"
    }

    $testResult = Test-ItemExistence $SearchPath.Key $Module.RequiredItems $SearchPath.SubFolder
    if ($testResult.Exists) {
        $Module.ModuleRoot = $testResult.Folder
        return $testResult.Folder
    }

    return $null
}

Register-EnvironmentModuleSearchPathType ([EnvironmentModuleCore.SearchPath]::TYPE_ENVIRONMENT_VARIABLE) 10 {
    param([EnvironmentModuleCore.SearchPath] $SearchPath, [EnvironmentModuleCore.EnvironmentModuleInfo] $Module)
    $directory = $([environment]::GetEnvironmentVariable($SearchPath.Key))

    if([string]::IsNullOrEmpty($SearchPath.Key)) {
        Write-Warning "Environment Variable search path without key specified"
    }

    if(-not $directory) {
        Write-Verbose "No directory found under environment variable '$($SearchPath.Key)'"
        return $null
    }

    Write-Verbose "Checking environment search path $($SearchPath.Key) -> $directory"
    $testResult = (Test-ItemExistence $directory $Module.RequiredItems $SearchPath.SubFolder)
    if ($testResult.Exists) {
        $Module.ModuleRoot = $testResult.Folder
        return $testResult.Folder
    }

    return $null
}

# ---------------------------------
# Required Item Extension Point
# ---------------------------------

$script:requiredItemTypes = @{}

function Register-EnvironmentModuleRequiredItemType([string] $Type, [scriptblock] $Handler)
{
    $script:requiredItemTypes[$Type] = $Handler
}

Register-EnvironmentModuleRequiredItemType ([EnvironmentModuleCore.RequiredItem]::TYPE_FILE) {
    param([System.IO.DirectoryInfo] $Directory, [EnvironmentModuleCore.RequiredItem] $Item)

    if([string]::IsNullOrEmpty($Item.Value)) {
        Write-Warning "Required file without value specified"
    }

    $found = $false
    foreach($testItem in $item.Value.Split(";")) {
        if (-not (Test-Path (Join-Path "$($Directory.FullName)" "$testItem"))) {
            Write-Verbose "The file $testItem does not exist in folder $($Directory.FullName)"
        }
        else {
            $found = $true
            break
        }
    }

    return $found
}

# ---------------------------------
# Functions
# ---------------------------------

function Test-ItemExistence([string] $FolderPath, [EnvironmentModuleCore.RequiredItem[]] $Items, [string] $SubFolderPath) {
    <#
    .SYNOPSIS
    Check if the given folder contains all items given as second parameter.
    .DESCRIPTION
    This function will check if the folder does exist and if it contains all given items.
    .PARAMETER FolderPath
    The folder to check.
    .PARAMETER Items
    The items to check.
    .PARAMETER SubFolderPath
    The subfolder path that should be appended to the folder path.
    .OUTPUTS
    An anonymous object containing 2 values. "Exists": True if the folder does exist and if it contains all items, false otherwise.
    "Folder": The full path to the folder containing the file. The value is $null if no folder was found.
    #>
    if (-not $FolderPath) {
        Write-Error "No folder path given"
        return @{Exists=$false; Folder=$null}
    }

    if (-not $SubFolderPath) {
        $SubFolderPath = ""
    }

    Write-Verbose "Testing item exisiting in folder '$Folder' and subfolder '$SubFolderPath'"
    try {
        $folderCandidates = (Get-Item (Join-Path "$FolderPath" "$SubFolderPath" -ErrorAction SilentlyContinue) -ErrorAction SilentlyContinue) | Where-Object {$_.PsIsContainer}
    }
    catch {
        $folderCandidates = @()
    }

    foreach($folderCandidate in $folderCandidates) {
        $match = $true
        foreach($item in $Items) {
            $handler = $script:requiredItemTypes[$item.ItemType.ToUpper()]

            if($null -eq $handler) {
                Write-Warning "No handler for item type $($item.ItemType) found"
                $match = $false
            }
            else {
                $found = $handler.InvokeReturnAsIs($folderCandidate, $item)

                if(-not $found) {
                    $match = $false
                }
            }

            if($match -eq $false) {
                break
            }
        }

        if($match) {
            return @{Exists=$true; Folder=$folderCandidate.FullName}
        }
    }

    return @{Exists=$false; Folder=$null}
}

function Test-EnvironmentModuleRootDirectory([EnvironmentModuleCore.EnvironmentModuleInfo] $Module, [switch] $IncludeDependencies)
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
    if(($Module.RequiredItems.Length -gt 0) -and ($null -eq (Set-EnvironmentModuleRootDirectory $Module))) {
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

function Set-EnvironmentModuleRootDirectory
{
    <#
    .SYNOPSIS
    Find the root directory of the module that is either specified by a search path object. Store the value in the object.
    .DESCRIPTION
    This function will check the meta parameter of the given module and will identify the root directory of the module. The root directory is the first
    directory that contains all required items.
    .PARAMETER Module
    The module to handle.
    .OUTPUTS
    The path to the root directory or $null if it was not found.
    #>

    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param (
        [EnvironmentModuleCore.EnvironmentModuleInfo] $Module,
        [bool] $SilentMode
    )

    if((-not ([string]::IsNullOrEmpty($Module.ModuleRoot))) -and (Test-Path ($Module.ModuleRoot))) {
        return $Module.ModuleRoot
    }

    Write-Verbose "Searching root for $($Module.Name) with $($Module.SearchPaths.Count) search paths and $($Module.RequiredItems.Count) required items"

    if(($Module.SearchPaths.Count -eq 0) -and ($Module.RequiredItems.Count -gt 0)) {
        if(-not $SilentMode) {
            Write-Warning "The module $($Module.FullName) has no defined search paths. Please use the function Add-EnvironmentModuleSearchPath to specify the location"
        }
    }

    foreach($searchPath in $Module.SearchPaths)
    {
        $handler = $script:searchPathTypes[$searchPath.Type.ToUpper()]

        if($null -eq $handler) {
            if(-not $SilentMode) {
                Write-Warning "No handler for search path type $($searchPath.Type) found"
            }
            continue
        }

        $result = (($handler.Item1).InvokeReturnAsIs($searchPath, $Module))
        Write-Verbose "Handling search path $($searchPath.Key) returned with '$result'"

        if($null -eq $result) {
            Write-Verbose "Checking next search path"
            continue
        }

        return $result
    }

    $Module = $null
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
        Add-DynamicParameter 'ModuleFullName' String $runtimeParameterDictionary -Mandatory $false -Position 0 -ValidateSet $moduleSet
        Add-DynamicParameter 'IsLoadedDirectly' Bool $runtimeParameterDictionary -Mandatory $false -Position 1 -ValidateSet @($true, $false)
        Add-DynamicParameter 'ModuleFile' String $runtimeParameterDictionary -Mandatory $false -Position 2
        return $runtimeParameterDictionary
    }

    begin {
        # Bind the parameter to a friendly variable
        $ModuleFullName = $PsBoundParameters["ModuleFullName"]
        $IsLoadedDirectly = $PsBoundParameters["IsLoadedDirectly"]
        $ModuleFile = $PsBoundParameters["ModuleFile"]
    }

    process {
        $silentMode = $false
        if($silent) {
            $silentMode = $true
        }

        if($null -eq $IsLoadedDirectly) {
            $IsLoadedDirectly = $true
        }

        if($null -ne $ModuleFile) {
            $ModuleFullName = (Get-Module "$ModuleFile" -ListAvailable)[0].Name
            if($null -eq $ModuleFullName) {
                Write-Error "Unable to load module information from $ModuleFile, please specify a valid psd1 file."
                return
            }
        }

        $initialSilentLoadState = $script:silentLoad
        Import-RequiredModulesRecursive $ModuleFullName $IsLoadedDirectly (New-Object "System.Collections.Generic.HashSet[string]") $null $silentMode $ModuleFile | Out-Null
        $script:silentLoad = $initialSilentLoadState
    }
}

function Import-RequiredModulesRecursive([String] $ModuleFullName, [Bool] $LoadedDirectly, [System.Collections.Generic.HashSet[string]][ref] $KnownModules,
                                         [EnvironmentModuleCore.EnvironmentModuleInfo] $SourceModule = $null, [Bool] $SilentMode = $false, [String] $ModuleFile = $null)
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
    .PARAMETER SourceModule
    The module that has triggered the loading of this module (used when module is loaded as dependency).
    .PARAMETER SilentMode
    True if no outputs should be printed.
    .PARAMETER ModuleFile
    The module file to load. If no file is specified, the module is loaded from the PSModulePath.
    .OUTPUTS
    True if the module was loaded correctly, otherwise false.
    #>

    if($KnownModules.Contains($ModuleFullName) -and (0 -eq (Get-Module $ModuleFullName).Count)) {
        Write-Error "A circular dependency between the modules was detected"
        return $false
    }
    $KnownModules.Add($ModuleFullName) | Out-Null

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
    $module = New-EnvironmentModuleInfo -ModuleFullName $ModuleFullName -ModuleFile $ModuleFile

    $alreadyLoadedModules = $null
    if(($module.ModuleType -eq [EnvironmentModuleCore.EnvironmentModuleType]::Meta) -and ($LoadedDirectly)) {
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
    $moduleRoot = Set-EnvironmentModuleRootDirectory $module $SilentMode

    if (($module.RequiredItems.Length -gt 0) -and ($null -eq $moduleRoot)) {
        if(-not $SilentMode) {
            Write-InformationColored -InformationAction 'Continue' "Unable to find the root directory of module $($module.FullName) - Is the program correctly installed?" -ForegroundColor $Host.PrivateData.ErrorForegroundColor -BackgroundColor $Host.PrivateData.ErrorBackgroundColor
            Write-InformationColored -InformationAction 'Continue' "Use 'Add-EnvironmentModuleSearchPath' to specify the location." -ForegroundColor $Host.PrivateData.ErrorForegroundColor -BackgroundColor $Host.PrivateData.ErrorBackgroundColor
        }
        return $false
    }

    Write-Verbose "Children are loaded with directly state $loadDependenciesDirectly"
    $loadedDependencies = New-Object "System.Collections.Stack"

    if($module.Dependencies.Count -gt 0) {
        $dependencyIndex = 0
        foreach ($dependency in $module.Dependencies) {
            Write-Verbose "Importing dependency $dependency"

            $silentDependencyMode = $dependency.IsOptional
            $loadingResult = (Import-RequiredModulesRecursive $dependency.ModuleFullName $loadDependenciesDirectly $KnownModules $module $silentDependencyMode)
            if (-not $loadingResult) {
                if(-not ($dependency.IsOptional)) {
                    while ($loadedDependencies.Count -gt 0) {
                        Remove-EnvironmentModule ($loadedDependencies.Pop())
                    }
                    return $false
                }
            }
            else {
                $loadedDependencies.Push($dependency.ModuleFullName)
            }

            $dependencyIndex++
        }
    }

    # Create the temp directory
    (New-Item -ItemType directory -Force $module.TmpDirectory) | Out-Null

    # Set the parameter defaults
    $module.Parameters.Keys | ForEach-Object { Set-EnvironmentModuleParameterInternal $_ $module.Parameters[$_] $ModuleFullName $false }

    # Load the module itself
    $module = New-Object "EnvironmentModuleCore.EnvironmentModule" -ArgumentList ($module, $LoadedDirectly, $SourceModule)

    Write-Verbose "Importing the module $ModuleFullName into the Powershell environment"
    $psModuleName = $ModuleFile
    if([string]::IsNullOrEmpty($ModuleFile)) {
        $psModuleName = $ModuleFullName
    }

    try {
        Import-Module $psModuleName -Scope Global -Force -ArgumentList $module, $SilentMode
    }
    catch {
        if(-not $SilentMode) {
            Write-Error $_.Exception.Message
        }
        return $false
    }

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
        [void] (New-Event -SourceIdentifier "EnvironmentModuleLoaded" -EventArguments $module, $LoadedDirectly, $SilentMode)
        Remove-Module $ModuleFullName -Force
        return $true
    }

    # Print the summary
    if(($module.ModuleType -eq [EnvironmentModuleCore.EnvironmentModuleType]::Meta) -and ($LoadedDirectly) -and (-not $SilentMode)) {
        Show-EnvironmentSummary -ModuleBlacklist $alreadyLoadedModules
    }

    [void] (New-Event -SourceIdentifier "EnvironmentModuleLoaded" -EventArguments $module, $LoadedDirectly, $SilentMode)
    return $true
}

function Mount-EnvironmentModuleInternal([EnvironmentModuleCore.EnvironmentModule] $Module, [Bool] $SilentMode)
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
            [String] $actualValue = [Environment]::GetEnvironmentVariable($pathInfo.Variable)
            Write-Verbose "Handling path for variable $($pathInfo.Variable) with joined value $joinedValue"

            if ($pathInfo.PathType -eq [EnvironmentModuleCore.PathType]::SET) {
                Write-Verbose "Joined Set-Path: $($pathInfo.Variable) = $joinedValue"
                if($script:loadedEnvironmentModuleSetPaths.ContainsKey($Module.FullName)) {
                    $script:loadedEnvironmentModuleSetPaths[$Module.FullName][$pathInfo.Variable] = $actualValue
                }
                else {
                    $script:loadedEnvironmentModuleSetPaths[$Module.FullName] = @{$pathInfo.Variable = $actualValue}
                }

                [Environment]::SetEnvironmentVariable($pathInfo.Variable, $joinedValue, "Process")
            }

            if($joinedValue -eq "")  {
                continue
            }

            if ($pathInfo.PathType -eq [EnvironmentModuleCore.PathType]::PREPEND) {
                Write-Verbose "Joined Prepend-Path: $($pathInfo.Variable) = $joinedValue"
                Add-EnvironmentVariableValue -Variable $pathInfo.Variable -Value $joinedValue -Append $false
            }
            if ($pathInfo.PathType -eq [EnvironmentModuleCore.PathType]::APPEND) {
                Write-Verbose "Joined Append-Path: $($pathInfo.Variable) = $joinedValue"
                Add-EnvironmentVariableValue -Variable $pathInfo.Variable -Value $joinedValue -Append $true
            }
        }

        foreach ($aliasInfo in $Module.Aliases.Values) {
            Add-EnvironmentModuleAlias $aliasInfo

            Set-Alias -name $aliasInfo.Name -value $aliasInfo.Definition -scope "Global"
            if(($aliasInfo.Description -ne "") -and (-not $SilentMode)) {
                if(-not $SilentMode) {
                    Write-InformationColored -InformationAction 'Continue' $aliasInfo.Description -Foregroundcolor $Host.PrivateData.VerboseForegroundColor -BackgroundColor $Host.PrivateData.VerboseBackgroundColor
                }
            }
        }

        foreach ($functionInfo in $Module.Functions.Values) {
            Add-EnvironmentModuleFunction $functionInfo

            new-item -path function:\ -name "global:$($functionInfo.Name)" -value ([ScriptBlock]$functionInfo.Definition) -Force
        }

        Write-Verbose ("Register environment module with name " + $Module.Name + " and object " + $Module)

        Write-Verbose "Adding module $($Module.Name) to mapping"
        $script:loadedEnvironmentModules[$Module.Name] = $Module

        if($script:configuration["ShowLoadingMessages"]) {
            Write-InformationColored -InformationAction 'Continue' ("$($Module.FullName) loaded")
        }

        return $true
    }
}

function Show-EnvironmentSummary([EnvironmentModuleCore.EnvironmentModuleInfoBase[]] $ModuleBlacklist = $null)
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
    $functions = Get-EnvironmentModuleFunction -ReturnTopLevelFunction | Sort-Object -Property "Name"
    $parameters = Get-EnvironmentModuleParameter | Sort-Object -Property "Name"
    $modules = Get-ConcreteEnvironmentModules | Sort-Object -Property "FullName"

    Write-InformationColored -InformationAction 'Continue' ""
    Write-InformationColored -InformationAction 'Continue' "--------------------" -ForegroundColor $Host.PrivateData.WarningForegroundColor -BackgroundColor $Host.PrivateData.WarningBackgroundColor
    Write-InformationColored -InformationAction 'Continue' "Loaded Modules:" -ForegroundColor $Host.PrivateData.WarningForegroundColor -BackgroundColor $Host.PrivateData.WarningBackgroundColor

    $moduleBlackListNames = $ModuleBlacklist | Select-Object -ExpandProperty "FullName"
    $modules | ForEach-Object {
        if(-not ($moduleBlackListNames -match $_.FullName)) {
            Write-InformationColored -InformationAction 'Continue' "  * $($_.FullName)"
        }
    }

    Write-InformationColored -InformationAction 'Continue' "Available Functions:" -ForegroundColor $Host.PrivateData.WarningForegroundColor -BackgroundColor $Host.PrivateData.WarningBackgroundColor
    $functions | ForEach-Object {
        if(-not ($moduleBlackListNames -match $_.ModuleFullName)) {
            Write-InformationColored -InformationAction 'Continue' "  * $($_.Name) - " -NoNewline
            Write-InformationColored -InformationAction 'Continue' $_.ModuleFullName -ForegroundColor $Host.PrivateData.VerboseForegroundColor -BackgroundColor $Host.PrivateData.VerboseBackgroundColor
        }
    }

    Write-InformationColored -InformationAction 'Continue' "Available Aliases:" -ForegroundColor $Host.PrivateData.WarningForegroundColor -BackgroundColor $Host.PrivateData.WarningBackgroundColor
    $aliases | ForEach-Object {
        if(-not ($moduleBlackListNames -match $_.ModuleFullName)) {
            Write-InformationColored -InformationAction 'Continue' "  * $($_.Name) - " -NoNewline
            Write-InformationColored -InformationAction 'Continue' $_.Description -ForegroundColor $Host.PrivateData.VerboseForegroundColor -BackgroundColor $Host.PrivateData.VerboseBackgroundColor
        }
    }

    Write-InformationColored -InformationAction 'Continue' "Available Parameters:" -ForegroundColor $Host.PrivateData.WarningForegroundColor -BackgroundColor $Host.PrivateData.WarningBackgroundColor
    $parameters | ForEach-Object {
        Write-InformationColored -InformationAction 'Continue' "  * $($_.Name) - " -NoNewline
        Write-InformationColored -InformationAction 'Continue' $_.Value -ForegroundColor $Host.PrivateData.VerboseForegroundColor -BackgroundColor $Host.PrivateData.VerboseBackgroundColor
    }
    Write-InformationColored -InformationAction 'Continue' "--------------------" -ForegroundColor $Host.PrivateData.WarningForegroundColor -BackgroundColor $Host.PrivateData.WarningBackgroundColor
    Write-InformationColored -InformationAction 'Continue' ""
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
        [switch] $Silent
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

        $oldUserParameters = Get-EnvironmentModuleParameter "*" -UserDefined

        Remove-EnvironmentModule $moduleFullName -Force

        Import-EnvironmentModule $newModuleFullName -IsLoadedDirectly:$module.IsLoadedDirectly -Silent:$Silent

        foreach($parameter in $oldUserParameters) {
            $newParameter = (Get-EnvironmentModuleParameter $parameter.Name)
            if(($null -ne $newParameter) -and ($newParameter.IsUserDefined -eq $False)) {
                Set-EnvironmentModuleParameterInternal $parameter.Name $parameter.Value "" $True
            }
        }

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

function Add-EnvironmentModuleAlias([EnvironmentModuleCore.AliasInfo] $AliasInfo)
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
        $newValue = New-Object "System.Collections.Generic.List[EnvironmentModuleCore.AliasInfo]"
        $newValue.Add($AliasInfo)
        $script:loadedEnvironmentModuleAliases.Add($AliasInfo.Name, $newValue)
    }
}

function Add-EnvironmentModuleFunction([EnvironmentModuleCore.FunctionInfo] $FunctionDefinition)
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
        $newValue = New-Object "System.Collections.Generic.List[EnvironmentModuleCore.FunctionInfo]"
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