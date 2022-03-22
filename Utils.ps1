function Add-DynamicParameter {
    <#
    .SYNOPSIS
    Add a new dynamic parameter to the parameter sets.
    .PARAMETER Name
    The name of the parameter to add.
    .PARAMETER Type
    The type of the parameter to add. Switch is supported as well, but not recommended (they should be defined as static parameters).
    .PARAMETER ParamDict
    The dictionary containing the parameter definitions. This value is passed by reference.
    .PARAMETER Mandatory
    Indicates if the parameter is mandatory.
    .PARAMETER Position
    The position of the parameter. The first parmeter must have position 0.
    .PARAMETER ValidateSet
    The validate set to use.
    .EXAMPLE
    Populate the parameter set with 3 parameters.
        Add-DynamicParameter 'DynamicParam' String $runtimeParameterDictionary -Mandatory $True -Position 0 -ValidateSet @("Dyn1", "Dyn2", "Dyn3")
        Add-DynamicParameter 'DynamicParamInt' Int $runtimeParameterDictionary -Mandatory $True -Position 1
        Add-DynamicParameter 'DynamicParamSwitch' Switch $runtimeParameterDictionary -Mandatory $False -Position 2
    .NOTES
    If at least one dynamic parameter is required, all non switch parameters should be dynamic. Otherwise positional attribute set will not work.
    #>
    param(
        [Parameter(Mandatory=$True)]
        [String] $Name,
        [Parameter(Mandatory=$True)]
        [System.Type] $Type,
        [Parameter(Mandatory=$True)]
        [System.Management.Automation.RuntimeDefinedParameterDictionary][ref] $ParamDict,
        [Boolean] $Mandatory = $false,
        [Int] $Position = $null,
        [Array] $ValidateSet = $null
    )
    process {
        $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

        # Create and set the parameters' attributes
        $parameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $parameterAttribute.Mandatory = $Mandatory

        if($null -ne $Position) {
            $parameterAttribute.Position = $Position
        }

        # Add the attributes to the attributes collection
        $attributeCollection.Add($parameterAttribute)

        # Add the validation set to the attributes collection
        if(($null -ne $ValidateSet) -and ($ValidateSet.Count -gt 0)) {
            $validateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($ValidateSet)
            $attributeCollection.Add($validateSetAttribute)
        }

        # Create and return the dynamic parameter
        $runtimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($Name, $Type, $attributeCollection)
        $ParamDict.Add($Name, $runtimeParameter)
    }
}

function Show-SelectDialogue([array] $Options, [string] $Header)
{
    <#
    .SYNOPSIS
    Show a selection dialog for the given values.
    .DESCRIPTION
    This function will show an input selection for all values that are defined.
    .PARAMETER Options
    The options to display.
    .PARAMETER Header
    The question to display.
    .OUTPUTS
    The selected value or $null if no element was selected.
    #>
    Write-InformationColored -InformationAction 'Continue' "$($Header):"
    Write-InformationColored -InformationAction 'Continue' ""
    $indexPathMap = @{}

    if($Options.Count -eq 0) {
        return $null
    }

    if($Options.Count -eq 1) {
        return $Options[0]
    }

    $i = 1
    foreach ($option in $Options) {
        Write-InformationColored -InformationAction 'Continue' "[$i] $option"
        $indexPathMap[$i] = $option
        $i++
    }

    $selectedIndex = Read-Host -Prompt " "
    Write-Verbose "Got selected index $selectedIndex and possibilities $($Options.Count)"
    if(-not($selectedIndex -match '^[0-9]+$')) {
        Write-Error "Invalid index specified"
        return $null
    }

    $selectedIndex = [int]($selectedIndex)
    if(($selectedIndex -lt 1) -or ($selectedIndex -gt $Options.Length)) {
        Write-Error "Invalid index specified"
        return $null
    }

    Write-Verbose "The selected option is $($indexPathMap[$selectedIndex])"
    Write-Verbose "Calculated selected index $selectedIndex - for possibilities $Options"

    return $indexPathMap[$selectedIndex]
}

function Show-ConfirmDialogue([string] $Message) {
    <#
    .SYNOPSIS
    Show a dialogue that asks for confirmation.
    .DESCRIPTION
    This function will show the displayed message and requires a yes/no response from the user.
    .PARAMETER Header
    The question to display.
    .OUTPUTS
    $True if the user has answered "yes".
    #>
    $result = Read-Host "$Message [y/n]"

    if($result.ToLower() -ne "y") {
        return $false
    }

    return $true
}

function Test-PathPartOfEnvironmentVariable([String] $Path, [String] $Variable) {
    <#
    .SYNOPSIS
    Check if a path is part of an environment variable.
    .DESCRIPTION
    The function will check if the given path is part of the specified environment variable.
    .PARAMETER Path
    The path to check.
    .PARAMETER Variable
    The environment variable to consider.
    .OUTPUTS
    $True if the path was identified in the variable.
    #>

    $variableValue = [System.Environment]::GetEnvironmentVariable($Variable)
    if(-not $variableValue) {
        return $false
    }

    $Path = [System.IO.Path]::GetFullPath($Path) # We normalize the path
    foreach($part in $variableValue.Split([IO.Path]::PathSeparator)) {
        if([String]::IsNullOrEmpty($part)) {
            continue
        }

        $part = [System.IO.Path]::GetFullPath($part)
        if($part.Equals($Path, [System.StringComparison]::InvariantCultureIgnoreCase)) {
            return $true
        }
    }

    return $false
}

<#
    Taken from https://blog.kieranties.com/2018/03/26/write-information-with-colours
    .SYNOPSIS
        Writes messages to the information stream, optionally with
        color when written to the host.
    .DESCRIPTION
        An alternative to Write-Host which will write to the information stream
        and the host (optionally in colors specified) but will honor the
        $InformationPreference of the calling context.
        In PowerShell 5.0+ Write-Host calls through to Write-Information but
        will _always_ treats $InformationPreference as 'Continue', so the caller
        cannot use other options to the preference variable as intended.
#>
Function Write-InformationColored {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object] $MessageData,
        [ConsoleColor] $ForegroundColor = $Host.UI.RawUI.ForegroundColor, # Make sure we use the current colours by default
        [ConsoleColor] $BackgroundColor = $Host.UI.RawUI.BackgroundColor,
        [Switch] $NoNewline
    )

    $msg = [System.Management.Automation.HostInformationMessage]@{
        Message         = $MessageData
        ForegroundColor = $ForegroundColor
        BackgroundColor = $BackgroundColor
        NoNewline       = $NoNewline.IsPresent
    }

    Write-Information $msg
}

function Resolve-NotExistingPath {
    <#
    .SYNOPSIS
        Calls Resolve-Path but works for files that don't exist.
    .REMARKS
        From http://devhawk.net/blog/2010/1/22/fixing-powershells-busted-resolve-path-cmdlet
    #>
    param (
        [string] $FilePath
    )

    $FilePath = Resolve-Path $FilePath -ErrorAction SilentlyContinue `
                                       -ErrorVariable _frperror
    if (-not($FilePath)) {
        $FilePath = $_frperror[0].TargetObject
    }

    return $FilePath
}