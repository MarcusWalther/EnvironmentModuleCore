
function Import-EnvironmentModulesConfiguration
{
    [CmdletBinding()]
    param(
        [String] $ConfigurationFile
    )
    process {
        if(-not (Test-Path $ConfigurationFile)) {
            return
        }
        $script:configuration = Import-Clixml $ConfigurationFile
    }
}

function Export-EnvironmentModulesConfiguration
{
    [CmdletBinding()]
    param(
        [String] $ConfigurationFile = $null
    )
    process {
        if([string]::IsNullOrEmpty($ConfigurationFile)) {
            $ConfigurationFile = $script:configurationFilePath
        }

        $script:configuration | Export-Clixml $ConfigurationFile
    }
}

function Set-EnvironmentModuleConfigurationValue
{
    [CmdletBinding()]
    param(
    )
    DynamicParam {
        $runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $moduleSet = @("NugetApiKey", "NugetSource", "DefaultModuleStoragePath")
        Add-DynamicParameter 'ParameterName' String $runtimeParameterDictionary -Mandatory $True -Position 0 -ValidateSet $moduleSet
        Add-DynamicParameter 'Value' String $runtimeParameterDictionary -Mandatory $True -Position 1

        return $runtimeParameterDictionary
    }
    begin {
        # Bind the parameter to a friendly variable
        $ParameterName = $PsBoundParameters["ParameterName"]
        $Value = $PsBoundParameters["Value"]
    }
    process {
        $script:configuration[$ParameterName] = $Value
        Export-EnvironmentModulesConfiguration
    }
}