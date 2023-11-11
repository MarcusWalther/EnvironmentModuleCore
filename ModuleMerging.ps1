function Join-EnvironmentModuleInfos([EnvironmentModuleCore.EnvironmentModuleInfo] $Base, [EnvironmentModuleCore.EnvironmentModuleInfo] $Other) {
    <#
    .SYNOPSIS
    Merges the paths, parameters and dependencies of the specified module into this object. Existing values are not overwritten.
    The merge itself is performed directly in the base module.
    .PARAMETER Base
    The base module to consider for merging. Values of this module have a higher priority than the values of the other module.
    .PARAMETER Other
    The module defining the values to merge.
    #>

    
}