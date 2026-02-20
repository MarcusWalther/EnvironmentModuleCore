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
    $result.Dependencies = @()

    # Merge all dependencies
    $allDependencies = [ordered] @{}

    foreach($dependency in $Base.Dependencies) {
        $nameParts = Split-EnvironmentModuleName $dependency.ModuleFullName
        if($null -eq $nameParts) {
            continue
        }

        $allDependencies[$nameParts.Name] = @($dependency)
    }

    foreach($dependency in $Other.Dependencies) {
        # Check if the name is correctly formated
        $nameParts = Split-EnvironmentModuleName $dependency.ModuleFullName
        if($null -eq $nameParts) {
            continue
        }

        $allDependencies = Select-MergeEnvironmentModule -Dependency $dependency -KnownDependencies $allDependencies
    }

    # Set all dependencies
    foreach($dependencies in $allDependencies) {
        foreach($subDependency in $dependencies.Values) {
            $result.Dependencies += $subDependency
        }
    }

    # Merge all parameters
    foreach($parameterKey in $Other.Parameters.Keys) {
        $result.Parameters[$parameterKey] = $Other.Parameters[$parameterKey]
    }

    # Merge all path manipulations
    foreach($pathDefinition in $Other.Paths) {
        $result.AddPath($pathDefinition) | Out-Null
    }

    return $result
}

function Select-MergeEnvironmentModule([EnvironmentModuleCore.DependencyInfo] $Dependency, [hashtable] $KnownDependencies) {
    $moduleNameParts = Split-EnvironmentModuleName $Dependency.ModuleFullName
    $name = $moduleNameParts.Name

    if(-not $knownDependencies.ContainsKey($name)) {
        # No module with the same name was part of the dependencies
        $KnownDependencies[$name] = @($Dependency)
        return $KnownDependencies
    }

    $firstDependency = $KnownDependencies[$name][0]
    if($firstDependency.Priority -lt $Dependency.Priority) {
        Write-Verbose "The dependency to $($Dependency.ModuleFullName) has a higher priority than the dependency to $($firstDependency.ModuleFullName)"
        $orderedDependencies = $KnownDependencies[$name] + @($Dependency) | Sort-Object -Descending {$_.Priority}
        $firstDependency = $orderedDependencies

        if($Dependency.IsOptional) {
            $orderedDependencies = $KnownDependencies[$name].Sort()
            $KnownDependencies[$name] = $orderedDependencies

            foreach($subDependency in $orderedDependencies) {
                $subDependency.IsOptional = $true
            }
            
            return $KnownDependencies
        }
        else {
            $KnownDependencies[$name] = @($Dependency)
            return $KnownDependencies
        }
    }

    if($firstDependency.IsOptional) {
        # The dependendency is optional -> all dependencies of the same modules are marked as optional as well
        $KnownDependencies[$name] = $KnownDependencies[$name] + @([EnvironmentModuleCore.DependencyInfo]::new($Dependency.ModuleFullName, $true, $Dependency.Priority))
        return $KnownDependencies
    }

    if($true -eq (Test-ConflictModule $Dependency.ModuleFullName $firstDependency.ModuleFullName)) {
        return $KnownDependencies
    }

    $KnownDependencies[$name] = @($Dependency)
    return $KnownDependencies
}