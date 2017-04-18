# Creata a empty collection of known and loaded environment modules first
[HashTable] $loadedEnvironmentModules = @{}

$moduleFileLocation = $MyInvocation.MyCommand.ScriptBlock.Module.Path
$moduleCacheFileLocation = [IO.Path]::Combine($moduleFileLocation, "..\ModuleCache.xml")

$script:environmentModules = @()
$silentUnload = $false

function Load-EnvironmentModuleCache()
{
	<#
	.SYNOPSIS
	Load the environment modules cache file.
	.DESCRIPTION
	This function will load all environment modules that part of the cache file and will provide them in the environemtModules list.
	.OUTPUTS
	No output is returned.
	#>
	$script:environmentModules = @()
	if(-not (test-path $moduleCacheFileLocation))
	{
		return
	}
	
	$script:environmentModules = Import-CliXml -Path $moduleCacheFileLocation
}

function Update-EnvironmentModuleCache()
{
	<#
	.SYNOPSIS
	Search for all modules that depend on the environment module and add them to the cache file.
	.DESCRIPTION
	This function will clear the cache file and later iterate over all modules of the system. If the module depends on the environment module, 
	it is added to the cache file.
	.OUTPUTS
	No output is returned.
	#>
	$script:environmentModules = @()
	foreach ($module in (Get-Module -ListAvailable)) {
		Write-Verbose "Module $($module.Name) depends on $($module.RequiredModules)"
		$isEnvironmentModule = ("$($module.RequiredModules)" -match "EnvironmentModules")
		if($isEnvironmentModule) {
			Write-Verbose "Environment module $($module.Name) found"
			$script:environmentModules = $script:environmentModules + $module.Name
		}
	}

	Export-Clixml -Path "$moduleCacheFileLocation" -InputObject $script:environmentModules
}

# Check if the cache file is available -> create it if not
if(test-path $moduleCacheFileLocation)
{
	Load-EnvironmentModuleCache
}
else
{
	Update-EnvironmentModuleCache
}

# Include all required functions
. "${PSScriptRoot}\EnvironmentModules.ps1"