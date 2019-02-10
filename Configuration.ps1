
function Import-EnvironmentModulesConfiguration
{
    <#
    .SYNOPSIS
    Import the configuration from the given file.
    .PARAMETER ConfigurationFile
    The configuration file to read. The content type must be XML.
    #>
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
    <#
    .SYNOPSIS
    Export the internal configuration to a file.
    .PARAMETER ConfigurationFile
    The configuration file to write. The content type will be XML.
    #>
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
        $moduleSet = @("DefaultModuleStoragePath", "ShowLoadingMessages", "CreateDefaultModulesByArchitecture",
                       "CreateDefaultModulesByName", "CreateDefaultModulesByMajorVersion")
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