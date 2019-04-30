Register-EnvironmentModuleRequiredItemType "GIT_REMOTE" {
    param([System.IO.DirectoryInfo] $Directory, [EnvironmentModuleCore.RequiredItem] $Item)

    if([string]::IsNullOrEmpty($Item.Value)) {
        Write-Warning "Required git remote without value specified"
    }

    Write-Verbose "Searching for remote $Item.Value in $Directory.FullName"

    Push-Location
    Set-Location $Directory.FullName
    $remotes = $null
    try {
        $remotes = git remote -v
    }
    catch {
        Write-Warning "Error executing git"
    }
    Pop-Location

    if([string]::IsNullOrEmpty($remotes)) {
        return $false
    }

    Write-Verbose "Found the following remotes in '$Directory': $remotes"
    $matchResult = $remotes -match $Item.Value
    if(($null -eq $matchResult) -or ($matchResult.Length -eq 0)) {
        Write-Verbose "'$($Item.Value)' does not match"
        return $false
    }

    Write-Verbose "'$($Item.Value)' does match"
    return $true
}