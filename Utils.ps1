function Compare-PossibleNullStrings([String] $String1, [String] $String2)
{
	<#
	.SYNOPSIS
	Utility function which is able to compare two strings that are possibly $null.
	.DESCRIPTION
	Compare the given strings. If one of the is $null, the result is $false. If both are $null,
	the result is $true. Otherwise the string value is compared and the result returned.
	.PARAMETER String1
	the first string that should be compared.
	.PARAMETER String2
	the second string that should be compared.
	.OUTPUTS
	the boolean result of the comparison.
	#>
	if(!$String1) {
		if(!$String2) {
			return $true
		}
		return $false
	}
	if(!$String2) {
		return $false;
	}
	
	return ($String1 -eq $String2)
}

function Find-Directory([string]$directoryName, [string[]]$searchDirectories) {
	foreach($directory in $searchDirectories)
	{
		if(!(Test-Path $directory)) {
			continue
		}	
		$completePath = Join-Path $directory $directoryName
		if(Test-Path($completePath))
		{
			return $completePath
		}
	}
	return $null
}

function Find-FirstFile([string]$filePattern, [string]$directorySubPath, [string[]]$searchDirectories) {
	foreach($directory in $searchDirectories)
	{
		if(!(Test-Path $directory)) {
			continue
		}	
		$completePath = Join-Path $directory $directorySubPath
		if(!(Test-Path $completePath)) {
			continue
		}
		$files = Get-ChildItem $completePath -Filter $filePattern
		if($files) {
			return (Join-Path $completePath $files[0])
		}
	}
	return $null
}

function Find-FirstFileRegex([string]$fileRegexPattern, [string]$directorySubPath, [string[]]$searchDirectories) {
	foreach($directory in $searchDirectories)
	{
		if(!(Test-Path $directory)) {
			continue
		}	
		$completePath = Join-Path $directory $directorySubPath
		if(!(Test-Path $completePath)) {
			continue
		}
		$files = Get-ChildItem $completePath | Where-Object { $_.Name -match $fileRegexPattern }
		if($files) {
			return (Join-Path $completePath $files[0])
		}
	}
	return $null
}

function Expand-EnvironmentPaths([String] $environmentPath, [String] $subPath)
{
	$result = @()
	Foreach ($path in Split-String -Separator ";" -Input $environmentPath)
	{ 
		$result = $result + (Join-Path $path $subPath)
	}
	
	return $result
}