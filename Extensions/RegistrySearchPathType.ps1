Register-EnvironmentModuleSearchPathType "REGISTRY" 25 {
    param([EnvironmentModuleCore.SearchPath] $SearchPath, [EnvironmentModuleCore.EnvironmentModuleInfo] $Module)

    Write-Verbose "Checking registry search path $($SearchPath.Key)"

    if([string]::IsNullOrEmpty($SearchPath.Key)) {
        Write-Warning "Registry search path without key specified"
    }

    try {
        $registryValue = $null
        if($SearchPath.Key.EndsWith("\")) {
            $propertyPath = $SearchPath.Key
            $registryValue = (Get-Item -ErrorAction SilentlyContinue -Path "Registry::$propertyPath").GetValue("")
        }
        else {
            Write-Verbose "Splitted registry search path into path '$propertyPath' and name '$propertyName'"
            $propertyName = Split-Path -Leaf $SearchPath.Key
            $propertyPath = Split-Path $SearchPath.Key
            $registryValue = Get-ItemProperty -ErrorAction SilentlyContinue -Name "$propertyName" -Path "Registry::$propertyPath" | Select-Object -ExpandProperty "$propertyName"
        }

        Write-Verbose "Got registry value $registryValue"
        if ($null -eq $registryValue) {
                Write-Verbose "Unable to find the registry value $($SearchPath.Key)"
                return $null
            }

            Write-Verbose "Found registry value $registryValue"
            $folder = $registryValue
            if(-not [System.IO.Directory]::Exists($folder)) {
                Write-Verbose "The folder $folder does not exist, using parent"
                $folder = Split-Path -parent $registryValue
            }

            Write-Verbose "Checking the folder $folder"

            $testResult = Test-ItemExistence $folder $Module.RequiredItems $SearchPath.SubFolder
            if ($testResult.Exists) {
                Write-Verbose "The folder $($testResult.Folder) contains the required files"
                $Module.ModuleRoot = $testResult.Folder
                return $testResult.Folder
            }
        }
    catch {
        return $null
    }

    return $null
}