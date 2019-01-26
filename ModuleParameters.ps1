function Set-EnvironmentModuleParameterInternal {
    param(
        [String] $Parameter,
        [String] $Value
    )

    $script:environmentModuleParameters[$Parameter] = $Value
}

function Set-EnvironmentModuleParameter {
    [cmdletbinding()]
    Param()
    DynamicParam {
        $runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        $parameterNames = $Script:environmentModuleParameters.Keys
        Add-DynamicParameter 'Parameter' String $runtimeParameterDictionary -Mandatory $True -Position 0 -ValidateSet $parameterNames

        Add-DynamicParameter 'Value' String $runtimeParameterDictionary -Mandatory $True -Position 1

        return $runtimeParameterDictionary
    }
    begin {
        $Parameter = $PsBoundParameters['Parameter']
        $Value = $PsBoundParameters['Value']
    }
    process {
        Set-EnvironmentModuleParameterInternal $Parameter $Value
    }
}

function Get-EnvironmentModuleParameter {
    [cmdletbinding()]
    Param()
    DynamicParam {
        $runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        $parameterNames = $script:environmentModuleParameters.Keys
        Add-DynamicParameter 'Parameter' String $runtimeParameterDictionary -Mandatory $True -Position 0 -ValidateSet $parameterNames

        return $runtimeParameterDictionary
    }
    begin {
        $Parameter = $PsBoundParameters['Parameter']
    }
    process {
        $script:environmentModuleParameters[$Parameter]
    }
}