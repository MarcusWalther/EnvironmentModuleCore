function Set-EnvironmentModuleParameterInternal {
    <#
    .SYNOPSIS
    Set the parameter value to the given value.
    .PARAMETER Parameter
    The name of the parameter to set. If the parameter does not exist, it is created.
    .PARAMETER Value
    The value to set.
    .PARAMETER ModuleFullName
    The module that has specified the value. A user change should be indicated by an empty string.
    #>

    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [String] $Parameter,
        [String] $Value,
        [String] $ModuleFullName = ""  # Empty string means: set by user
    )

    $knownValue = $script:environmentModuleParameters[$Parameter]
    if($null -eq $knownValue) {
        $knownValue = New-Object "EnvironmentModuleCore.ParameterInfo" -ArgumentList $Parameter, $ModuleFullName, $Value
    }
    $knownValue.Value = $Value
    $knownValue.ModuleFullName = $ModuleFullName
    $script:environmentModuleParameters[$Parameter] = $knownValue
}

function Set-EnvironmentModuleParameter {
    <#
    .SYNOPSIS
    This function is called by the user in order to change a parameter value.
    .PARAMETER Parameter
    The name of the parameter to set. If the parameter does not exist, it is created.
    .PARAMETER Value
    The value to set.
    .PARAMETER Silent
    No validation set is used for the parmeter name. If the parameter does not exist, no action is performed and no
    error is printed.
    #>

    [cmdletbinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    Param([switch] $Silent)
    DynamicParam {
        $runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        if(-not $Silent) {
            $parameterNames = $Script:environmentModuleParameters.Keys
            Add-DynamicParameter 'Parameter' String $runtimeParameterDictionary -Mandatory $True -Position 0 -ValidateSet $parameterNames
        }
        else {
            Add-DynamicParameter 'Parameter' String $runtimeParameterDictionary -Mandatory $True -Position 0
        }

        Add-DynamicParameter 'Value' String $runtimeParameterDictionary -Mandatory $False -Position 1

        return $runtimeParameterDictionary
    }
    begin {
        $Parameter = $PsBoundParameters['Parameter']
        $Value = $PsBoundParameters['Value']
    }
    process {
        if(-not ($script:environmentModuleParameters[$Parameter])) {
            return
        }
        if([string]::IsNullOrEmpty($Value)) {
            $Value = ""
        }

        Set-EnvironmentModuleParameterInternal $Parameter $Value ""
    }
}

function Get-EnvironmentModuleParameter {
    <#
    .SYNOPSIS
    Get all parameter definitions matching the given search criterias.
    .PARAMETER ParameterName
    The name of the parameter to return (can contain wildcards).
    .OUTPUTS
    All identified paramter info objects matching the search criterias.
    #>
    [cmdletbinding()]
    Param(
        [string] $ParameterName = "*"
    )
    process {
        foreach($parameter in $script:environmentModuleParameters.Keys) {
            if(-not ($parameter -like $ParameterName)) {
                continue
            }

            $script:environmentModuleParameters[$parameter]
        }
    }
}