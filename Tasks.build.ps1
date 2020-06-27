param(
	[System.IO.DirectoryInfo] $OutputFolder,
	[string] $NugetSource = "nuget.org",
	[string] $PowershellExecutable = "pwsh",
	[string] $Suffix = $null,
	[switch] $AllowPrerelease
)

task Prepare {
	<#
	.SYNOPSIS
	Download the latest compiled .Net Standard libraries from Nuget that are required to use the module.
	#>

	Push-Location
	Set-Location "$PSScriptRoot"

	# Create the nuget directory
	$nugetDirectory = "Nuget"

	New-Item -ItemType directory -Force $nugetDirectory
	Set-Location $nugetDirectory

	$cmdArguments = "install", "EnvironmentModuleCore", "-Source", "$NugetSource"
	if($AllowPrerelease) {
		$cmdArguments += '-Prerelease'
	}

	nuget $cmdArguments

	$libraries = (Get-ChildItem "." "lib" -Recurse) | ForEach-Object {Get-ChildItem $_ (Join-Path "netstandard2.0" "*.dll")} | Select-Object -ExpandProperty "Fullname"
	foreach($library in $libraries) {
		Copy-Item $library ".."
		Write-Verbose "Found library $library"
	}

	Pop-Location
}

task Test {
	<#
	.SYNOPSIS
	Run the script analyser over the module code. The pester tests for the module are 
	#>
	# Install-Module PSScriptAnalyzer
	Invoke-ScriptAnalyzer -Recurse -Severity Warning "$PSScriptRoot"

	if ((Get-ChildItem "Test").count -eq 0) {
		Write-Warning "The test folder submodule was not checked out correctly"
		return
	}

	mkdir "TestResults" -Force
	& "$PowershellExecutable" -NoProfile -Command {Import-Module "./EnvironmentModuleCore.psd1"; Set-Location "Test"; Invoke-Pester -Script "./Tests.ps1" -OutputFile "../TestResults/Test-Pester.xml" -OutputFormat NUnitXml}
}

task Pack {
    <#
    .SYNOPSIS
	Copy the relevant files to the specified output folder.
	#>
	if($null -eq $OutputFolder) {
		Write-Error "Please specify the output folder parameter"
		return
	}

	Push-Location
	Set-Location "$PSScriptRoot"

	# Create the package directory
	if($null -eq $OutputFolder) {
		$OutputFolder = (Join-Path "package" "EnvironmentModuleCore")
	}

	if(Test-Path $OutputFolder) {
		Remove-Item -Recurse -Force $OutputFolder
	}

	New-Item -ItemType directory $OutputFolder

	# Copy the relevant items to the package folder
	Copy-Item "*.ps*1" $OutputFolder -Exclude "Tasks.build.ps1"
	Copy-Item "*.dll" $OutputFolder
	Copy-Item "LICENSE.md" $OutputFolder
	Copy-Item "*.ps1xml" $OutputFolder
	Copy-Item "Templates" $OutputFolder -Recurse
	Copy-Item "Extensions" $OutputFolder -Recurse
}

task Deploy {
    <#
    .SYNOPSIS
	Copy the relevant files to the specified output folder and publish it via nuget afterwards.
	#>

    Publish-Module -Path "$PackageFolder" -Repository "$NugetSource" -Verbose #-NuGetApiKey "$NuGetApiKey"
}