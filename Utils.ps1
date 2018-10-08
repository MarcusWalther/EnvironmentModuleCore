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
        if($null -ne $ValidateSet) {
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
    .OUTPUTS
    The selected value or $null if no element was selected.
    #>
    Write-Host "$($Header):"
    Write-Host
    $indexPathMap = @{}

    $i = 1
    foreach ($option in $Options) {
        Write-Host "[$i] $option"
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