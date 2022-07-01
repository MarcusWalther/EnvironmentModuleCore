function Expand-ValuePlaceholders {
    <#
    .SYNOPSIS
    Replace value placeholders of format "%[<Type>]{<Name>}%" with the concrete value.
    .PARAMETER Value
    The value to modify.
    .PARAMETER Module
    The associated module.
    .OUTPUTS
    The rendered value.
    #>
    param (
        [string] $Value,
        [EnvironmentModuleCore.EnvironmentModuleInfo] $Module
    )

    if(-not ($Value.StartsWith("%") -and $Value.EndsWith("%"))) {
        return $Value
    }

    $Value = $Value.Substring(1, $Value.Length-2)
    $ModuleRoot = $Module.ModuleRoot
    $ModuleBase = $Module.ModuleBase
    $Value = $Value.Replace("{ModuleRoot}", $ModuleRoot)
    $Value = $Value.Replace("{ModuleBase}", $ModuleBase)
    $Value = $Value.Replace("{TmpDirectory}", $Module.TmpDirectory)

    if($Value.StartsWith("[Path]")) {
        $Value = $Value.Substring(6)
        return Resolve-NotExistingPath $Value
    }

    return $Value
}

function Expand-PathSeparators {
    <#
    .SYNOPSIS
    Replace the path separator ":;" or ";:" by the platform specific separator.
    .PARAMETER Value
    The string to modify.
    .OUTPUTS
    The rendered string.
    #>
    param (
        [string] $Value
    )

    $Value.Replace(";:", [IO.Path]::PathSeparator).Replace(":;", [IO.Path]::PathSeparator)
}