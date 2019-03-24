Register-EnvironmentModuleRequiredItemType "GIT_REMOTE" {
    param([System.IO.DirectoryInfo] $Directory, [EnvironmentModuleCore.RequiredItem] $Item)

    Push-Location
    Set-Location $Directory.FullName
    # TODO: Sorround with try-catch
    $remotes = git remote -v
    Pop-Location
    $matchResult = $remotes -match "$($Item.Value) "
    if($null -eq $matchResult) {
        return $false
    }

    return $true
}