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
    .PARAMETER VirtualEnvironment
    The virtual environment that the parameter belongs to.
    .PARAMETER Force
    Overwrite the old value, even if it is user defined.
    #>

    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [String] $Parameter,
        [String] $Value,
        [String] $ModuleFullName = "",  # Empty string means: set by user
        [Bool] $IsUserDefined = $false,
        [String] $VirtualEnvironment = "Default",
        [Switch] $Force
    )

    $parameterKey = [System.Tuple[string, string]]::new($Parameter, $VirtualEnvironment)
    $knownValue = $script:environmentModuleParameters[$parameterKey]
    $valueAdded = $false
    if($null -eq $knownValue) {
        $knownValue = New-Object "EnvironmentModuleCore.ParameterInfo" -ArgumentList $Parameter, $ModuleFullName, $Value, $IsUserDefined, $VirtualEnvironment
        $valueAdded = $true
    }

    # The previous value is user defined and this is the default -> only change it if force is set
    if($knownValue.IsUserDefined -and (-not $IsUserDefined)) {
        if(-not $Force) {
            Write-Verbose "Value $Parameter is not changed, because a user defined value is already set"
            return
        }
    }
    $knownValue.IsUserDefined = $IsUserDefined
    $knownValue.Value = $Value
    $knownValue.ModuleFullName = $ModuleFullName
    $script:environmentModuleParameters[$parameterKey] = $knownValue

    if($valueAdded) {
        Update-VirtualParameterEnvironments
    }

    [void] (New-Event -SourceIdentifier "EnvironmentModuleParameterChanged" -EventArguments $Parameter, $knownValue)
}

function Remove-EnvironmentModuleParameterInternal {
    <#
    .SYNOPSIS
    Remove the parameter from the internal storage and virtual environments.
    .PARAMETER Parameter
    The name of the parameter to remove. If the parameter does not exist, nothing is done.
    #>

    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [String] $Parameter
    )

    $virtualEnvironments = $script:environmentModuleParameters.Keys | ForEach-Object { if($_.Item1 -eq $Parameter) { $_.Item2 }}
    $virtualEnvironments | ForEach-Object {
        $parameterKey = [System.Tuple[string, string]]::new($Parameter, $_)
        $script:environmentModuleParameters.Remove($parameterKey) | Out-Null
    }

    if($virtualEnvironments) {
        Update-VirtualParameterEnvironments
    }
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
    .PARAMETER Force
    Overwrite the old value, even if it is user defined.
    .PARAMETER VirtualEnvironment
    The virtual environment that the parameter belongs to.
    #>

    [cmdletbinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    Param([switch] $Silent, [switch] $Force)
    DynamicParam {
        $runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        if(-not $Silent) {
            $parameterNames = $Script:environmentModuleParameters.Keys | Foreach-Object {$_.Item1}
            Add-DynamicParameter 'Parameter' String $runtimeParameterDictionary -Mandatory $True -Position 0 -ValidateSet $parameterNames
        }
        else {
            Add-DynamicParameter 'Parameter' String $runtimeParameterDictionary -Mandatory $True -Position 0
        }

        Add-DynamicParameter 'Value' String $runtimeParameterDictionary -Mandatory $False -Position 1
        Add-DynamicParameter 'VirtualEnvironment' String $runtimeParameterDictionary -Mandatory $False -Position 2

        return $runtimeParameterDictionary
    }
    begin {
        $Parameter = $PsBoundParameters['Parameter']
        $Value = $PsBoundParameters['Value']
        $VirtualEnvironment = $PsBoundParameters['VirtualEnvironment']
        if([string]::IsNullOrEmpty($VirtualEnvironment)) {
            $VirtualEnvironment = $script:activeVirtualEnvironment
        }
    }
    process {
        if([string]::IsNullOrEmpty($Value)) {
            $Value = ""
        }

        $IsUserDefined = $null -eq (Get-PSCallStack | Where-Object {$_.Command -like "*.psm1"})

        Set-EnvironmentModuleParameterInternal $Parameter $Value "" $IsUserDefined -Force:$Force -VirtualEnvironment:$VirtualEnvironment
    }
}

function Get-EnvironmentModuleParameter {
    <#
    .SYNOPSIS
    Get all parameter definitions matching the given search criterias.
    .PARAMETER ParameterName
    The name of the parameter to return (can contain wildcards).
    .PARAMETER VirtualEnvironment
    The virtual environment to consider.
    .OUTPUTS
    All identified parameter info objects matching the search criterias.
    #>
    [cmdletbinding()]
    Param(
        [string] $ParameterName = "*",
        [string] $VirtualEnvironment = $null,
        [Switch] $UserDefined
    )
    process {
        if([string]::IsNullOrEmpty($VirtualEnvironment)) {
            $VirtualEnvironment = $script:activeVirtualEnvironment
        }

        $parameterMatches = [System.Collections.Generic.Dictionary[string, string]]::new() # Map the parametername to the environment
        foreach($parameter in $script:environmentModuleParameters.Values) {
            if(-not ($parameter.Name -like $ParameterName)) {
                continue
            }

            if($UserDefined -and ($parameter.IsUserDefined -eq $false)) {
                continue
            }

            if($parameter.VirtualEnvironment -eq "Default") {
                # Only use the default value if no concrete value for the environment is specified (fallback)
                if(-not $parameterMatches.ContainsKey($parameter.Name)) {
                    $parameterMatches[$parameter.Name] = $parameter.VirtualEnvironment
                }
                continue
            }

            if(-not ($parameter.VirtualEnvironment -like $VirtualEnvironment)) {
                continue
            }

            $parameterMatches[$parameter.Name] = $parameter.VirtualEnvironment
        }

        foreach($parameterName in $parameterMatches.Keys) {
            $virtualEnvironment = $parameterMatches[$parameterName]
            $parameterKey = [System.Tuple[string, string]]::new($parameterName, $virtualEnvironment)
            $script:environmentModuleParameters[$parameterKey]
        }
    }
}

function Update-VirtualParameterEnvironments {
    <#
    .SYNOPSIS
    Iterates over all parameters and checks if the virtual environment collection is up to date.
    #>
    $virtualEnvironments = [System.Collections.Generic.HashSet[string]]::new()
    $virtualEnvironments.Add("Default") | out-null
    $script:environmentModuleParameters.Keys | Foreach-Object {
        $virtualEnvironments.Add($_.Item2) | out-null
    }

    $script:virtualEnvironments = ($virtualEnvironments | ForEach-Object {$_}) | Sort-Object
}

function Get-VirtualParameterEnvironments {
    <#
    .SYNOPSIS
    Gets all virtual parameter environments defined by the modules.
    .OUTPUTS
    The virtual environments.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    $script:virtualEnvironments
}

function Enable-VirtualParameterEnvironment {
    <#
    .SYNOPSIS
    Enable the virtual environment parameter of the given environment.
    .PARAMETER VirtualEnvironment
    The virtual environment to load. "Default" if the default environment should be loaded.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [String] $VirtualEnvironment = "Default"
    )

    $script:activeVirtualEnvironment = $VirtualEnvironment
    [void] (New-Event -SourceIdentifier "EnvironmentModuleVirtualParameterEnvironmentEnabled" -EventArguments $VirtualEnvironment)
}