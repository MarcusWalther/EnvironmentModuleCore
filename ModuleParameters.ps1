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
    .PARAMETER IsUserDefined
    True if the value was defined manually by the user.
    #>

    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [String] $Parameter,
        [String] $Value,
        [String] $ModuleFullName = "",  # Empty string means: set by user
        [Bool] $IsUserDefined = $false
    )

    $knownValue = $script:environmentModuleParameters[$Parameter]
    if($null -eq $knownValue) {
        $knownValue = New-Object "EnvironmentModuleCore.ParameterInfo" -ArgumentList $Parameter, $ModuleFullName, $Value, $IsUserDefined
    }
    $knownValue.IsUserDefined = $IsUserDefined
    $knownValue.Value = $Value
    $knownValue.ModuleFullName = $ModuleFullName
    $script:environmentModuleParameters[$Parameter] = $knownValue
}

function Remove-EnvironmentModuleParameterInternal {
    <#
    .SYNOPSIS
    Remove the parameter from the internal storage.
    .PARAMETER Parameter
    The name of the parameter to remove. If the parameter does not exist, nothing is done.
    #>

    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [String] $Parameter
    )

    $script:environmentModuleParameters.Remove($Parameter)
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

        $IsUserDefined = $null -eq (Get-PSCallStack | Where-Object {$_.Command -like "*.psm1"})

        Set-EnvironmentModuleParameterInternal $Parameter $Value "" $IsUserDefined
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
        [string] $ParameterName = "*",
        [Switch] $UserDefined
    )
    process {
        foreach($parameter in $script:environmentModuleParameters.Values) {
            if(-not ($parameter.Name -like $ParameterName)) {
                continue
            }

            if($UserDefined -and ($parameter.IsUserDefined -eq $false)) {
                continue
            }

            $parameter
        }
    }
}