
function Import-EnvironmentModuleCoreConfiguration
{
    <#
    .SYNOPSIS
    Import the configuration from the given file.
    .PARAMETER ConfigurationFile
    The configuration file to read. The content type must be XML.
    #>
    [CmdletBinding(ConfirmImpact='Low', SupportsShouldProcess=$true)]
    param(
        [String] $ConfigurationFile
    )
    process {
        if ( -not $PSCmdlet.ShouldProcess("Import environment module configuration")) {
            return
        }

        if(-not (Test-Path $ConfigurationFile)) {
            return
        }
        $script:configuration = Import-Clixml $ConfigurationFile
    }
}

function Export-EnvironmentModuleCoreConfiguration
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
    <#
    .SYNOPSIS
    Set a configuration value influencing the behaviour of the environment module engine. The configuration value is stored persistently.
    .PARAMETER ParameterName
    The name of the configuration parameter to set.
    .PARAMETER Value
    The value set.
    #>
    [CmdletBinding(ConfirmImpact='Low', SupportsShouldProcess=$true)]
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
        if ( -not $PSCmdlet.ShouldProcess("Change environment module configuration")) {
            return
        }

        $script:configuration[$ParameterName] = $Value
        Export-EnvironmentModuleCoreConfiguration
    }
}