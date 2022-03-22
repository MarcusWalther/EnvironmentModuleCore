function Expand-ValuePlaceholders {
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

    if($Value.StartsWith("[Path]")) {
        $Value = $Value.Substring(6)
        return Resolve-NotExistingPath $Value
    }

    return $Value
}