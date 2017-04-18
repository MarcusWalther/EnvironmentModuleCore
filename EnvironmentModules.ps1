# Depends on the logic of EnvironmentModules.psm1

function Mount-EnvironmentModule([String] $Name, [String] $Root, [String] $Version, [String] $Architecture, [System.Management.Automation.PSModuleInfo] $Info, 
							   [System.Management.Automation.ScriptBlock] $CreationDelegate, [System.Management.Automation.ScriptBlock] $DeletionDelegate) {
	<#
	.SYNOPSIS
	Creates a new environment module object out of the given parameters. After that, the creationDelegate is called, which can export environment variables or aliases.
	.DESCRIPTION
	Each environment module must be available as 'EnvironmentModules.EnvironmentModule'-object, which holds all information about the exported environment variables and aliases. 
	This function is a factory-function that generates a new 'EnvironmentModules.EnvironmentModule'-object with the given name, program-version 
	and architecture. After the creation is completed, the code given in the creationDelegate is invoked. If the module is removed from the environment, the deletionDelegate
	is invoked.
	.PARAMETER Name
	The name of the environment module. That is usually the same as the powershell module name. 
	.PARAMETER Root
	The root directory of the program which is loaded through the environment module. 
	.PARAMETER Version
	The version of the program that is loaded through the powershell module. This is not be the version of the powershell-module!
	.PARAMETER Architecture
	The architecture of the program that is loaded through the powershell module. This value is unused at the moment.
	.PARAMETER Info
	The powershell module that should be registered. This is usually '$MyInvocation.MyCommand.ScriptBlock.Module'
	.PARAMETER CreationDelegate
	The code that should be executed when the environment module is loaded. The code should take 2 arguments, the generated module that 
	can be filled with further information and the root directory of the module.
	.PARAMETER DeletionDelegate
	The code that should be executed when the environment module is removed. This is just a wrapper for the OnRemove delegate.
	.OUTPUTS
	A boolean value that indicates if the environment module was successfully created.
	.NOTES
	With the current concept it's impossible to get the description and other information from the module manifest.
	#>
	if($Root) {
		$moduleInfos = Split-EnvironmentModuleName $Name
		if(!$moduleInfos) {
			Write-Error ("The name of the enivronment module '" + $Name + "'cannot be split into its parts")
			return $null
		}
		if($Version) {
			$moduleInfos[1] = $Version
		}
		if($Architecture) {
			$moduleInfos[2] = $Architecture
		}
		
		Write-Verbose ("Creating environment module with name '" + $moduleInfos[0] + "', version '" + $moduleInfos[1] + "' and architecture '" + $moduleInfos[2] + "'")
		[EnvironmentModules.EnvironmentModule] $module = New-Object EnvironmentModules.EnvironmentModule($moduleInfos[0], $moduleInfos[1], $moduleInfos[2], $moduleInfos[3])
		$module = ($CreationDelegate.Invoke($module, $Root))[0]
		$successfull = Mount-EnvironmentModuleInternal($module)
		$Info.OnRemove = $DeletionDelegate

		return $true
	}
	else {
		Write-Host ($Name + " not found") -foregroundcolor "DarkGray"
	}
	return $false
}

function Split-EnvironmentModuleName([String] $Name)
{
	<#
	.SYNOPSIS
	Splits the given name into an array with 4 parts (name, version, architecture, additionalOptions).
	.DESCRIPTION
	Split a name string that either has the format 'Name-Version-Architecture' or just 'Name'. The output is 
	an array with the 4 parts (name, version, architecture, additionalOptions). If a value was not specified, 
	$null is returned at the according array index.
	.PARAMETER Name
	The name-string that should be splitted.
	.OUTPUTS
	A string array with 4 parts (name, version, architecture, additionalOptions) 
	#>
	$detailedRegex = ([regex]'([0-9A-Za-z]+)-(([0-9]+_[0-9]+)|(DEF|DEV|NIGHTLY))-([0-9A-Za-z]+)(-[0-9A-Za-z]+)*$').Matches($name);
	if($detailedRegex.Groups) 
	{
		$addionalOption = ""
		if ($detailedRegex.Groups.Count -gt 6) { $addionalOption = $detailedRegex.Groups[6] }
		
		return $detailedRegex.Groups[1], $detailedRegex.Groups[2], $detailedRegex.Groups[5], $addionalOption
	}
	else
	{
		$simpleRegex = ([regex]'([0-9A-Za-z]+)').Matches($Name);
		if(!$simpleRegex.Groups) {
			Write-Host ("The environment module name " + $Name + " is not correctly formated. It must be 'Name-Version-Architecture' or just 'Name'") -foregroundcolor "Red"
			return $null
		}
		return $simpleRegex.Groups[1], $null, $null, $null
	}
}

function Split-EnvironmentModule([EnvironmentModules.EnvironmentModule] $Module)
{
	<#
	.SYNOPSIS
	Converts the given environment module into an array with 4 parts (name, version, architecture, additionalOptions).
	.DESCRIPTION
	Converts an environment module into an array with 4 parts (name, version, architecture, additionalOptions), to make 
	it comparable to the output of the Split-EnvironmentModuleName function.
	.PARAMETER Module
	The module object that should be transformed.
	.OUTPUTS
	A string array with 4 parts (name, version, architecture, additionalOptions) 
	#>
	return $Module.Name, $Module.Version, $Module.Architecture, $Module.AdditionalOptions
}

function Compare-EnvironmentModuleInfos([String[]] $Module1, [String[]] $Module2)
{
	<#
	.SYNOPSIS
	Compares two given module information if their name, version and architecture is equal.
	.DESCRIPTION
	Compares two given module information if their name, version and architecture is equal. The additional attributes are ignored at the moment. 
	The module information can be generated with the help of the functions 'Split-EnvironmentModuleName' and 'Split-EnvironmentModule'.
	.PARAMETER Module1
	The first module information that should be compared.
	.PARAMETER Module2
	The second module information that should be compared.
	.OUTPUTS
	$true if the name, version and architecture values are equal. Otherwise $false
	#>
	Write-Verbose ("  - Name equal? " + (Compare-PossibleNullStrings $Module1[0] $Module2[0]))
	Write-Verbose ("  - Version equal? " + (Compare-PossibleNullStrings $Module1[1] $Module2[1]))
	Write-Verbose ("  - Architecture equal? " + (Compare-PossibleNullStrings $Module1[2] $Module2[2]))
	return ((Compare-PossibleNullStrings $Module1[0] $Module2[0]) -and ((Compare-PossibleNullStrings $Module1[1] $Module2[1]) -and (Compare-PossibleNullStrings $Module1[2] $Module2[2])))
}

function Get-EnvironmentModule([String] $Name = $null)
{
	<#
	.SYNOPSIS
	Get the environment module object, loaded by the given module name.
	.DESCRIPTION
	This function will check if an environment module with the given name was loaded and will return it. The 
	name is just the name of the module, without version, architecture or other information.
	.PARAMETER Name
	The module name of the required module object.
	.OUTPUTS
	The EnvironmentModule-object if a module with the given name was already loaded. If no module with 
	name was found, $null is returned.
	#>
	if([string]::IsNullOrEmpty($Name)) {
		Get-LoadedEnvironmentModules
		return
	}
	
	$moduleInfos = Split-EnvironmentModuleName $Name
	if(!$moduleInfos) {
		return $null
	}
	
	Write-Verbose ("Try to find environment module with name '" + $Name + "'")
	foreach ($var in $loadedEnvironmentModules.GetEnumerator()) {
		Write-Verbose ("Checking " + (Get-EnvironmentModuleDetailedString $var.Value))
		$tmpModuleInfos = Split-EnvironmentModule $var.Value
		if(Compare-EnvironmentModuleInfos $moduleInfos $tmpModuleInfos) {
			return $var.Value
		}
	}
	
	return $null
}

function Get-EnvironmentModuleDetailedString([EnvironmentModules.EnvironmentModule] $Module)
{
	<#
	.SYNOPSIS
	This is the reverse function of Split-EnvironmentModuleName. It will convert the information stored in 
	the given EnvironmentModule-object to a String containing Name, Version, Architecture and additional options.
	.DESCRIPTION
	Convert the given EnvironmentModule to a String with the form Name-Version[Architecture]-AdditionalOptions.
	.PARAMETER Module
	The module that should be converted to a String.
	.OUTPUTS
	A string with the form Name-Version[Architecture]-AdditionalOptions.
	#>
	$resultString = $Module.Name
	if($Module.Version) {
		$resultString += "-" + $Module.Version
	}
	if($Module.Architecture) {
		$resultString += '-' + $Module.Architecture
	}
	return $resultString
}

function Mount-EnvironmentModuleInternal([EnvironmentModules.EnvironmentModule] $Module)
{
	<#
	.SYNOPSIS
	Deploy all the aliases and environment variables that are stored in the given module object to the environment.
	.DESCRIPTION
	This function will export all aliases and environment variables that are defined in the given EnvironmentModule-object. An error 
	is written if the module conflicts with another module that is already loaded.
	.PARAMETER Module
	The module that should be deployed.
	.OUTPUTS
	A boolean value that is $true if the module was loaded successfully. Otherwise the value is $false.
	#>
	process {
		if($loadedEnvironmentModules.ContainsKey($Module.Name))
		{
			Write-Verbose "The module name '$Module.Name' was found in the list of already loaded modules"
			if($loadedEnvironmentModules.Get_Item($Module.Name).Equals($Module)) {
				Write-Host ("The Environment-Module '" + (Get-EnvironmentModuleDetailedString $Module) + "' is already loaded.") -foregroundcolor "Red"
				return $false
			}
			else {
				Write-Host ("The module '" + (Get-EnvironmentModuleDetailedString $Module) + " conflicts with the already loaded module '" + (Get-EnvironmentModuleDetailedString $loadedEnvironmentModules.($Module.Name)) + "'") -foregroundcolor "Red"
				return $false
			}
		}
		
		foreach ($pathKey in $Module.PrependPaths.Keys)
		{
			[String] $joinedValue = $Module.PrependPaths[$pathKey] -join ';'
			if($joinedValue -eq "") 
			{
				continue
			}
			Write-Verbose "Joined Prepend-Path: $pathKey = $joinedValue"
			Add-EnvironmentVariableValue -Variable "$pathKey" -Value "$joinedValue" -Append $false			
		}
		
		foreach ($pathKey in $Module.AppendPaths.Keys)
		{
			[String] $joinedValue = $Module.AppendPaths[$pathKey] -join ';'
			if($joinedValue -eq "") 
			{
				continue
			}
			Write-Verbose "Joined Append-Path: $pathKey = $joinedValue"
			Add-EnvironmentVariableValue -Variable "$pathKey" -Value "$joinedValue" -Append $true			
		}
		
		foreach ($pathKey in $Module.SetPaths.Keys)
		{
			[String] $joinedValue = $Module.SetPaths[$pathKey] -join ';'
			Write-Verbose "Joined Set-Path: $pathKey = $joinedValue"
			[Environment]::SetEnvironmentVariable($pathKey, $joinedValue, "Process")
		}
		
		foreach ($alias in $Module.Aliases.Keys) {
			$aliasValue = $Module.Aliases[$alias]
			Set-Alias -name $alias -value $aliasValue.Item1 -scope "Global"
			if($aliasValue.Item2 -ne "") {
				Write-Host $aliasValue.Item2 -foregroundcolor "Green"
			}
		}
		
		Write-Verbose ("Register environment module with name " + $Module.Name + " and object " + $Module)
		if($Module.Version -ne "DEF")
		{
			$loadedEnvironmentModules[$Module.Name] = $Module
		}
		$Module.Load()
		Write-Host ((Get-EnvironmentModuleDetailedString $Module) + " loaded") -foregroundcolor "Yellow"
		return $true
	}
}

function Dismount-EnvironmentModule([String] $Name = $null, [EnvironmentModules.EnvironmentModule] $Module = $null)
{
	<#
	.SYNOPSIS
	Remove all the aliases and environment variables that are stored in the given module object from the environment.
	.DESCRIPTION
	This function will remove all aliases and environment variables that are defined in the given EnvironmentModule-object from the environment. An error 
	is written if the module was not loaded. Either specify the concrete environment module object or the name of the environment module you want to remove.
	.PARAMETER Name
	The name of the module that should be removed.
	.PARAMETER Module
	The module that should be removed.
	#>
	process {		
		if(!$Module) {
			if(!$Name) {
				Write-Host ("You must specify a module which should be removed, by either passing the name or the environment module object.") -foregroundcolor "Red"
			}
			$Module = (Get-EnvironmentModule $Name)
			if(!$Module) { return; }
		}
		
		if(!$loadedEnvironmentModules.ContainsKey($Module.Name))
		{
			Write-Host ("The Environment-Module $inModule is not loaded.") -foregroundcolor "Red"
			return
		}

		foreach ($pathKey in $Module.PrependPaths.Keys)
		{
			[String] $joinedValue = $Module.PrependPaths[$pathKey] -join ';'
			if($joinedValue -eq "") 
			{
				continue
			}
			Write-Verbose "Joined Prepend-Path: $pathKey = $joinedValue"
			Remove-EnvironmentVariableValue -Variable "$pathKey" -Value "$joinedValue"		
		}
		
		foreach ($pathKey in $Module.AppendPaths.Keys)
		{
			[String] $joinedValue = $Module.AppendPaths[$pathKey] -join ';'
			if($joinedValue -eq "") 
			{
				continue
			}
			Write-Verbose "Joined Append-Path: $pathKey = $joinedValue"
			Remove-EnvironmentVariableValue -Variable "$pathKey" -Value "$joinedValue"		
		}
		
		foreach ($pathKey in $Module.SetPaths.Keys)
		{
			[Environment]::SetEnvironmentVariable($pathKey, $null, "Process")
		}

		foreach ($alias in $Module.Aliases.Keys) {
			Remove-Item alias:$alias
		}

		if($Module.Version -ne "DEF")
		{
			$loadedEnvironmentModules.Remove($Module.Name)
			Write-Verbose ("Removing " + $Module.Name + " from list of loaded environment variables")
		}
		
		$Module.Unload()
		Remove-Module $Module.Name -Force
		if(!$silentUnload) {
			Write-Host ($Module.Name + " unloaded") -foregroundcolor "Yellow"
		}
		return
	}
}

function Get-LoadedEnvironmentModules()
{
	<#
	.SYNOPSIS
	Get all loaded environment module names.
	.DESCRIPTION
	This function will return a String list, containing the names of all loaded environment modules.
	.OUTPUTS
	The String list containing the names of all environment modules.
	#>
	[String[]]$values = $loadedEnvironmentModules.getEnumerator() | % { $_.Key }
	return $values
}

function Get-LoadedEnvironmentModulesFullName()
{
	<#
	.SYNOPSIS
	Get all loaded environment modules with full name.
	.DESCRIPTION
	This function will return a String list, containing the names of all loaded environment modules.
	.OUTPUTS
	The String list containing the names of all environment modules.
	#>
	[String[]]$values = $loadedEnvironmentModules.getEnumerator() | % { Get-EnvironmentModuleDetailedString($_.Value) }
	return $values
}

function Test-IsEnvironmentModuleLoaded([String] $Name)
{
	<#
	.SYNOPSIS
	Check if the environment module with the given name is already loaded.
	.DESCRIPTION
	This function will check if Import-Module was called for an enivronment module with the given name.
	.PARAMETER Name
	The name of the module that should be tested.
	.OUTPUTS
	$true if the environment module was already loaded, otherwise $false.
	#>
	$loadedModule = (Get-EnvironmentModule $Name)
	if(!$loadedModule) {
		return $false
	}
		
	return $true
}

function Add-EnvironmentVariableValue([String] $Variable, [String] $Value, [Bool] $Append = $true)
{
	<#
	.SYNOPSIS
	Add the given value to the desired environment variable.
	.DESCRIPTION
	This function will append or prepend the new value to the environment variable with the given name.
	.PARAMETER Variable
	The name of the environment variable that should be extended.
	.PARAMETER Value
	The new value that should be added to the environment variable.
	.PARAMETER Append
	Set this value to $true if the new value should be appended to the environment variable. Otherwise the value is prepended. 
	.OUTPUTS
	No output is returned.
	#>
	$tmpValue = [environment]::GetEnvironmentVariable($Variable,"Process")
	if(!$tmpValue)
	{
		$tmpValue = $Value
	}
	else
	{
		if($Append) {
			$tmpValue = "${tmpValue};${Value}"
		}
		else {
			$tmpValue = "${Value};${tmpValue}"
		}
	}
	[Environment]::SetEnvironmentVariable($Variable, $tmpValue, "Process")
}

function Remove-EnvironmentVariableValue([String] $Variable, [String] $Value)
{
	<#
	.SYNOPSIS
	Remove the given value from the desired environment variable.
	.DESCRIPTION
	This function will remove the given value from the environment variable with the given name. If the value is not part 
	of the environment variable, no changes are performed.
	.PARAMETER Variable
	The name of the environment variable that should be extended.
	.PARAMETER Value
	The new value that should be removed from the environment variable.
	.OUTPUTS
	No output is returned.
	#>
	$oldValue = [environment]::GetEnvironmentVariable($Variable,"Process")
	$allPathValues = $oldValue.Split(";")
	$allPathValues = ($allPathValues | Where {$_.ToString() -ne $Value.ToString()})
	$newValue = ($allPathValues -join ";")
	[Environment]::SetEnvironmentVariable($Variable, $newValue, "Process")
}

function Switch-EnvironmentModule
{	
	<#
	.SYNOPSIS
	Switch a already loaded environment module with a different one.
	.DESCRIPTION
	This function will unmount the giben enivronment module and will load the new one instead.
	.PARAMETER ModuleName
	The name of the environment module to unload.
	.PARAMETER NewModuleName
	The name of the new environment module to load.
	.OUTPUTS
	No output is returned.
	#>
	[CmdletBinding()]
	Param(
		[switch] $Force
	)
	DynamicParam {
		$RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
		
		$ModuleNameParameterName = 'ModuleName'
		$ModuleNameAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
		$ModuleNameParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
		$ModuleNameParameterAttribute.Mandatory = $true
		$ModuleNameParameterAttribute.Position = 0
		$ModuleNameAttributeCollection.Add($ModuleNameParameterAttribute)
		$ModuleNameArrSet = Get-LoadedEnvironmentModulesFullName
		$ModuleNameValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($ModuleNameArrSet)
		$ModuleNameAttributeCollection.Add($ModuleNameValidateSetAttribute)
		$ModuleNameRuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ModuleNameParameterName, [string], $ModuleNameAttributeCollection)
		$RuntimeParameterDictionary.Add($ModuleNameParameterName, $ModuleNameRuntimeParameter)

		$NewModuleNameParameterName = 'NewModuleName'		
		$NewModuleNameAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]		
		$NewModuleNameParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
		$NewModuleNameParameterAttribute.Mandatory = $true
		$NewModuleNameParameterAttribute.Position = 1
		$NewModuleNameAttributeCollection.Add($NewModuleNameParameterAttribute)		
		$NewModuleNameArrSet = $script:environmentModules
		$NewModuleNameValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($NewModuleNameArrSet)		
		$NewModuleNameAttributeCollection.Add($NewModuleNameValidateSetAttribute)
		$NewModuleNameRuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($NewModuleNameParameterName, [string], $NewModuleNameAttributeCollection)
		$RuntimeParameterDictionary.Add($NewModuleNameParameterName, $NewModuleNameRuntimeParameter)
		
		return $RuntimeParameterDictionary
	}
	
	begin {
		# Bind the parameter to a friendly variable
		$moduleName = $PsBoundParameters[$ModuleNameParameterName]
		$newModuleName = $PsBoundParameters[$NewModuleNameParameterName]
	}

	process {
		$module = Get-EnvironmentModule($moduleName)
		
		if (!$module) {
			Write-Error ("No loaded environment module named $moduleName")
			return
		}
		
		$moduleName = Get-EnvironmentModuleDetailedString($module)
		if($Force) {
			Remove-Module $moduleName -Force
		}
		else {
			Remove-Module $moduleName
		}
		
		Import-EnvironmentModule $newModuleName
	}
}

function Import-EnvironmentModule
{
	<#
	.SYNOPSIS
	Import the environment module.
	.DESCRIPTION
	This function will import the environment module into the scope of the console.
	.PARAMETER Name
	The name of the environment module.
	.OUTPUTS
	No outputs are returned.
	#>
	[CmdletBinding()]
	Param(
		# Any other parameters can go here
	)
	DynamicParam {
		# Set the dynamic parameters' name
		$ParameterName = 'Name'
		
		# Create the dictionary 
		$RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
	
		# Create the collection of attributes
		$AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
		
		# Create and set the parameters' attributes
		$ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
		$ParameterAttribute.Mandatory = $true
		$ParameterAttribute.Position = 0
	
		# Add the attributes to the attributes collection
		$AttributeCollection.Add($ParameterAttribute)
	
		# Generate and set the ValidateSet 
		$arrSet = $script:environmentModules
		$ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
	
		# Add the ValidateSet to the attributes collection
		$AttributeCollection.Add($ValidateSetAttribute)
	
		# Create and return the dynamic parameter
		$RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
		$RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
		return $RuntimeParameterDictionary
	}
	
	begin {
		# Bind the parameter to a friendly variable
		$Name = $PsBoundParameters[$ParameterName]
	}

	process {	
		$loadedModules = @{}
		Import-RequiredModulesRecursive -Name $Name -LoadedModules $loadedModules
	}
}

function Import-RequiredModulesRecursive([String] $Name, [System.Collections.Hashtable] $LoadedModules)
{
	<#
	.SYNOPSIS
	Import the environment module with the given name and all required environment modules.
	.DESCRIPTION
	This function will import the environment module into the scope of the console and will later iterate over all required modules to import them as well.
	.PARAMETER Name
	The name of the environment module to import.
	.PARAMETER LoadedModules
	The already loaded modules.
	.OUTPUTS
	No outputs are returned.
	#>
	if($LoadedModules.ContainsKey($Name)) {
		return;
	}

	Import-Module $Name -Scope Global
	
	$isLoaded = Test-IsEnvironmentModuleLoaded $Name
	$LoadedModules.Add($Name, $isLoaded)
	
	if(!$isLoaded) {
		#Write-Error "The module $Name was not loaded successfully"
		$silentUnload = $true
		Remove-Module $Name -Force
		$silentUnload = $false
		return
	}
	
	foreach ($module in Get-Module $Name | Select -ExpandProperty RequiredModules) {
		$isEnvironmentModule = $script:environmentModules -contains $module
		if($isEnvironmentModule) {
			Import-RequiredModulesRecursive $module $LoadedModules
		}
		else {
			Import-Module $module
		}
	}
}

function New-EnvironmentModule
{
	<#
	.SYNOPSIS
	Create a new environment module
	.DESCRIPTION
	This function will create a new environment module with the given parameter.
	.PARAMETER Name
	The name of the environment module to generate.
	.PARAMETER Author
	The author of the environment module. If this value is not specified, the system user name is used.
	.PARAMETER Description
	An optional description for the module.
	.OUTPUTS
	No outputs are returned.
	#>
	Param(
		[String] $Name,
		[String] $Author,
		[String] $Description,
		[String] $Version,
		[String] $Architecture,
		[String] $Executable
	)
	
	process {
		if([string]::IsNullOrEmpty($Name)) {
			Write-Error('A module name must be specified')
			return
		}
		if([string]::IsNullOrEmpty($Author)) {
			$Author = [Environment]::UserName
		}
		if([string]::IsNullOrEmpty($Description)) {
			$Description = "Empty Description"
		}		
		if([string]::IsNullOrEmpty($Executable)) {
			Write-Error('An executable must be specified')
			return
		}		
		
		$environmentModulePath = Resolve-Path (Join-Path $moduleFileLocation "..\")
		$moduleRootPath = Resolve-Path (Join-Path $environmentModulePath "..\")
		[EnvironmentModules.ModuleCreator]::CreateEnvironmentModule($Name, $moduleRootPath, $Description, $environmentModulePath, $Author, $Version, $Architecture, $Executable)
		Update-EnvironmentModuleCache
	}
}

function New-EnvironmentModuleFunction
{
	<#
	.SYNOPSIS
	Export the given function in global scope.
	.DESCRIPTION
	This function will export a module function in global scope. This will prevent the powershell from automtically explore the function if the module is not loaded.
	.PARAMETER Name
	The name of the function to export.
	.PARAMETER Value
	The script block to export.
	.OUTPUTS
	No outputs are returned.
	#>
	Param(
		[String] $Name,
		[System.Management.Automation.ScriptBlock] $Value
	)
	
	process {	
		new-item -path function:\ -name "global:$Name" -value $Value -Force
	}
}

function Copy-EnvironmentModule
{
	<#
	.SYNOPSIS
	Copy the given environment module under the given name and generate a new GUID.
	.DESCRIPTION
	This function will clone the given module and will specify a new GUID for it. If required, the module search path is adapted.
	.PARAMETER Module
	The module to copy.
	.PARAMETER NewName
	The new name of the module.
	.OUTPUTS
	No outputs are returned.
	#>
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
		[String] $NewName,
		[String] $Path
	)
	DynamicParam {
		# Set the dynamic parameters' name
		$ParameterName = 'ModuleName'
		
		# Create the dictionary 
		$RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
	
		# Create the collection of attributes
		$AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
		
		# Create and set the parameters' attributes
		$ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
		$ParameterAttribute.Mandatory = $true
		$ParameterAttribute.Position = 0
	
		# Add the attributes to the attributes collection
		$AttributeCollection.Add($ParameterAttribute)
	
		# Generate and set the ValidateSet 
		$arrSet = $script:environmentModules
		$ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
	
		# Add the ValidateSet to the attributes collection
		$AttributeCollection.Add($ValidateSetAttribute)
	
		# Create and return the dynamic parameter
		$RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
		$RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
		return $RuntimeParameterDictionary
	}
	
	begin {
		# Bind the parameter to a friendly variable
		$ModuleName = $PsBoundParameters[$ParameterName]
	}

	process {
		$matchingModules = (Get-Module -ListAvailable $ModuleName)
		if($matchingModules.Length -ne 1) {
			Write-Error 'Found multiple modules matching the name "$ModuleName"'
		}
		
		$ModuleFolder = (Get-Item $matchingModules[0].Path).Parent
		Write-Host 'Cloning module $ModuleFolder'
		
		if(not $Path) {
			$Path = (Get-Item $ModuleFolder).Parent
		}
		
		Copy-Item -Path $ModuleFolder -Destination 
		
	}
}