function Test-PartOfTmpDirectory([string] $Destination, [switch] $ShowError)
{
    <#
    .SYNOPSIS
    Check if the given folder is part of the configured temp folder for environment modules.
    .PARAMETER Destination
    The folder to check.
    .OUTPUTS
    True if the folder is part of the temporary directory.
    #>
    $tmpDirectory = (Resolve-Path $script:tmpEnvironmentRootPath)

    if($Destination.StartsWith($tmpDirectory)) {
        if($ShowError) {
            Write-Error "The target destination is part of the temporary directory. Please specify another directory or set the force parameter."
        }
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
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    Param(
        [String] $Name,
        [String] $Author = $null,
        [String] $Company = $null,
        [String] $Description = "",
        [String] $Version = "",
        [String] $Architecture = "",
        [String[]] $RequiredFiles = @(),
        [String[]] $SearchPaths = @(),
        [String[]] $Dependencies = @(),
        [hashtable] $Parameters = @{},
        [String] $Path = $null,
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
        if([string]::IsNullOrEmpty($Company)) {
            $Company = ""
        }
        if([string]::IsNullOrEmpty($Description)) {
            $Description = ""
        }
        if([string]::IsNullOrEmpty($Version)) {
            $Version = ""
        }
        if([string]::IsNullOrEmpty($Architecture)) {
            $Version = ""
        }

        $environmentModulePath = Resolve-Path (Join-Path $script:moduleFileLocation "..")

        if([string]::IsNullOrEmpty($Path)) {
            $Path = Select-ModulePath
        }

        if($null -eq $Path) {
            return
        }

        if((-not $Force) -and (Test-PartOfTmpDirectory $Path)) {
            throw "The Path is Part of the tmp directory. Specifiy the Force parameter."
        }

        $requiredItemsList = [System.Collections.Generic.List[EnvironmentModuleCore.RequiredItem]]::new()
        foreach($requiredFile in $RequiredFiles) {
            $requiredItemsList.Add([EnvironmentModuleCore.RequiredItem]::new([EnvironmentModuleCore.RequiredItem]::TYPE_FILE, $requiredFile))
        }

        $searchPathsList = [System.Collections.Generic.List[EnvironmentModuleCore.SearchPath]]::new()
        foreach($searchPath in $SearchPaths) {
            $priority = $script:searchPathTypes[[EnvironmentModuleCore.SearchPath]::TYPE_DIRECTORY].Item2 + 20 # Get the default priority of the type and increase it because it is custom
            $searchPathsList.Add([EnvironmentModuleCore.SearchPath]::new($searchPath, [EnvironmentModuleCore.SearchPath]::TYPE_DIRECTORY, $priority, "", $true))
        }

        $dependenciesList = [System.Collections.Generic.List[EnvironmentModuleCore.DependencyInfo]]::new()
        foreach($dependency in $Dependencies) {
            $dependenciesList.Add([EnvironmentModuleCore.DependencyInfo]::new($dependency, $false))
        }

        $parametersDictionary = [System.Collections.Generic.Dictionary[string, string]]::new()
        foreach($key in $Parameters.Keys) {
            $parametersDictionary[$key] = $Parameters[$key]
        }

        [EnvironmentModuleCore.ModuleCreator]::CreateEnvironmentModule($Name, $Path, $Description, $environmentModulePath, $Author, $Company, $Version, $Architecture, $requiredItemsList.ToArray(), $searchPathsList.ToArray(), $dependenciesList.ToArray(), $parametersDictionary)
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
    .PARAMETER ModuleFullName
    The module to copy.
    .PARAMETER NewModuleFullName
    The new name of the module.
    .PARAMETER Path
    The target directory for the created module files. If this parameter is empty, a selection dialogue is displayed.
    .PARAMETER Force
    If this flag is set, the module can be created in a temp file location as well.
    .PARAMETER SkipCacheUpdate
    If this flag is set, the Update-EnvironmentModule function is not called.
    .OUTPUTS
    No outputs are returned.
    #>
    [CmdletBinding()]
    Param(
        [Switch] $Force,
        [Switch] $SkipCacheUpdate,
        [Switch] $AskForPathSelection
    )
    DynamicParam {
        $runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        $moduleSet =  Get-NonTempEnvironmentModules | Select-Object -ExpandProperty FullName
        Add-DynamicParameter 'ModuleFullName' String $runtimeParameterDictionary -Mandatory $True -Position 0 -ValidateSet $moduleSet

        Add-DynamicParameter 'NewModuleFullName' String $runtimeParameterDictionary -Mandatory $True -Position 1
        Add-DynamicParameter 'Path' String $runtimeParameterDictionary -Mandatory $False -Position 2

        return $runtimeParameterDictionary
    }

    begin {
        # Bind the parameter to a friendly variable
        $ModuleFullName = $PsBoundParameters['ModuleFullName']
        $NewModuleFullName = $PsBoundParameters['NewModuleFullName']
        $Path = $PsBoundParameters['Path']
    }

    process {
        $matchingModules = (Get-Module -ListAvailable $ModuleFullName)
        if($matchingModules.Length -lt 1) {
            Write-Error "Unable to find module matching name '$ModuleFullName'"
            return
        }
        if($matchingModules.Length -gt 1) {
            Write-Warning "Found multiple modules matching the name '$ModuleFullName'"
        }

        $moduleFolder = ($matchingModules[0]).ModuleBase
        $destination = Resolve-Path (Join-Path $moduleFolder '..')

        if($Path) {
            $destination = $Path
        }
        else {
            if($AskForPathSelection) {
                $selectedPath = Select-ModulePath

                if($null -eq $selectedPath) {
                    return
                }

                $destination = $selectedPath
            }
        }

        $destination = Join-Path $destination $NewModuleFullName

        if((-not $Force) -and (Test-PartOfTmpDirectory $selectedPath -ShowError)) {
            return
        }

        if((Test-Path $destination) -and (-not $Force)) {
            Write-Error "The folder $destination does already exist"
            return
        }

        $_ = New-Item -ItemType directory $destination -Force

        Write-Verbose "Cloning module $ModuleFullName to $destination"

        $filesToCopy = Get-ChildItem -File $moduleFolder
        $directoriesToCopy = Get-ChildItem -Directory $moduleFolder

        Write-Verbose "Found $($filesToCopy.Length) files to copy"

        foreach($file in $filesToCopy) {
            Write-Verbose "Handling file $file"
            $length = $file.Name.Length - $file.Extension.Length
            $shortName = $file.Name.Substring(0, $length)
            $newFileName = $file.Name

            Write-Verbose "Checking if `"$shortName`" matches `"$ModuleFullName`""
            if("$shortName" -match "$ModuleFullName") {
                $newFileName = "$($NewModuleFullName)$($file.Extension)"
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

            ($fileContent.Replace("$ModuleFullName", "$NewModuleFullName")) > "$newFullName"
        }

        foreach($directory in $directoriesToCopy) {
            Write-Verbose "Handling directory $directory"
            Copy-Item -Recurse -Force -Path $directory.FullName -Destination $destination
        }

        if(-not $SkipCacheUpdate) {
            Update-EnvironmentModuleCache
        }
    }
}

# This argument completer is used by Copy-EnvironmentModule for the file filter
Register-ArgumentCompleter -CommandName Copy-EnvironmentModule -ParameterName Path -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

    $env:PSModulePath.Split([IO.Path]::PathSeparator) | Where-Object {(Test-Path $_) -and -not (Test-PartOfTmpDirectory $_)} | Select-Object -Unique
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
    .PARAMETER FileFilter
    The files of the module to edit. Default is "*.pse1".
    .OUTPUTS
    No outputs are returned.
    #>
    [CmdletBinding()]
    Param()
    DynamicParam {
        $runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        $moduleSet = Get-AllEnvironmentModules | Select-Object -ExpandProperty FullName
        Add-DynamicParameter 'ModuleFullName' String $runtimeParameterDictionary -Mandatory $True -Position 0 -ValidateSet $moduleSet

        Add-DynamicParameter 'FileFilter' String $runtimeParameterDictionary -Mandatory $False -Position 1
        return $runtimeParameterDictionary
    }

    begin {
        # Bind the parameter to a friendly variable
        $ModuleFullName = $PsBoundParameters['ModuleFullName']
        $FileFilter = $PsBoundParameters['FileFilter']

        if(-not $FileFilter) {
            $FileFilter = '*.pse1'
        }
    }

    process {
        $modules = Get-Module -ListAvailable $ModuleFullName

        if(($null -eq $modules) -or ($modules.Count -eq 0)) {
            Write-Error "The module was not found"
            return
        }

        Get-ChildItem ($modules[0].ModuleBase) | Where-Object {$_ -like $FileFilter} | Invoke-Item
    }
}

# This argument completer is used by Edit-EnvironmentModule for the file filter
Register-ArgumentCompleter -CommandName Edit-EnvironmentModule -ParameterName FileFilter -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

    $module = Get-EnvironmentModule -ListAvailable $fakeBoundParameter["ModuleFullName"]

    if($module) {
        Get-ChildItem $module.ModuleBase
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
    $pathPossibilities = $env:PSModulePath.Split([IO.Path]::PathSeparator) | Where-Object {(Test-Path $_) -and -not (Test-PartOfTmpDirectory $_)} | Select-Object -Unique
    return Show-SelectDialogue $pathPossibilities "Select the target directory for the module"
}