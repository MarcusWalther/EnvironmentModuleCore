function Join-EnvironmentModuleInfos([EnvironmentModuleCore.EnvironmentModuleInfo] $Base, [EnvironmentModuleCore.EnvironmentModuleInfo] $Other) {
    <#
    .SYNOPSIS
    Merges the paths, parameters and dependencies of the specified module into a new module object.
    .PARAMETER Base
    The base module to consider for merging.
    .PARAMETER Other
    The module defining the values to merge. Values of this module have a higher priority than the values of the base module.
    .OUTPUTS
    The merged module info object.
    #>
    $result = [EnvironmentModuleCore.EnvironmentModuleInfo]::new($Base)

    # Merge all dependencies
    $otherModules = @{}
    $result.Dependencies = $Other.Dependencies

    foreach($dependency in $Other.Dependencies) {
        $nameParts = Split-EnvironmentModuleName $dependency.ModuleFullName
        if($null -eq $nameParts) {
            $result.Dependencies -= $dependency
            continue
        }

        $module = [EnvironmentModuleCore.EnvironmentModuleInfoBase]::new($ModuleFullName, $null, $nameParts.Name, $nameParts.Version, $nameParts.Architecture, $nameParts.AdditionalOptions, [EnvironmentModuleCore.EnvironmentModuleType]::Default)
        $otherModules[$nameParts.Name] = $module
    }

    foreach($dependency in $Base.Dependencies) {
        # Check if the name is correctly formated
        $nameParts = Split-EnvironmentModuleName $dependency.ModuleFullName
        if($null -eq $nameParts) {
            continue
        }

        $testResult = Test-ConflictsWithLoadedModules -ModuleFullName $dependency.ModuleFullName -LoadedEnvironmentModules $otherModules
        if(-not $testResult.Conflict) {
            # Check if the exact same module was already specified as dependency
            if($otherModules.Contains($nameParts.Name)) {
                continue
            }
            $result.Dependencies += $dependency
        }
        else {
            Write-Verbose "The dependency $($dependency.ModuleFullName) does conflict with the dependencies and is ignored"
        }
    }

    # Merge all parameters
    foreach($parameterKey in $Other.Parameters.Keys) {
        $result.Parameters[$parameterKey] = $Other.Parameters[$parameterKey]
    }

    # Merge all path manipulations
    foreach($pathDefinition in $Other.Paths) {
        $result.AddPath($pathDefinition)
    }

    return $result
}