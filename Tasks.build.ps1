param(
	[System.IO.DirectoryInfo] $Folder = (Join-Path "Nuget" "EnvironmentModuleCore"),
	[string] $NugetSource = "nuget.org",
	[string] $PowershellExecutable = "pwsh",
	[string] $Suffix = "local",
	[string] $NuGetApiKey = $null,
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

	dotnet nuget $cmdArguments

	$libraries = (Get-ChildItem "." "lib" -Recurse) | ForEach-Object {Get-ChildItem $_.FullName (Join-Path "netstandard2.0" "*.dll")} | Select-Object -ExpandProperty "FullName"
	foreach($library in $libraries) {
		Copy-Item $library ".."
		Write-Verbose "Found library $library"
	}

	Pop-Location
	Remove-Item -Recurse -Force "Nuget"
}

task Test {
	<#
	.SYNOPSIS
	Run the script analyser over the module code. The pester tests for the module are 
	#>

	if ((Get-ChildItem "Test").count -eq 0) {
		Write-Warning "The test folder submodule was not checked out correctly"
		return
	}

	New-Item -ItemType Directory "TestResults" -Force | Out-Null

	& "$PowershellExecutable" -NoProfile -Command { 
		Import-Module Pester
		Import-Module (Join-Path "." "EnvironmentModuleCore.psd1")

		$files = ((Get-ChildItem "*.ps1") | Where-Object { ($_.Name -ne "Tasks.build.ps1") -and ($_.Name -ne "SetupEnvironment.ps1") } | Select-Object -ExpandProperty "FullName" )
		Set-Location "Test"
		$pesterConfig = [PesterConfiguration]::Default
		$pesterConfig.Run.Path = "."
		$pesterConfig.TestResult.OutputPath = "../TestResults/TestResults.xml"
		$pesterConfig.TestResult.Enabled = $true

		$pesterConfig.CodeCoverage.Enabled = $true
		$pesterConfig.CodeCoverage.Path = $files
		$pesterConfig.Output.Verbosity = "Detailed"
		$pesterConfig.CodeCoverage.OutputPath = "../TestResults/Coverage.xml"
		Invoke-Pester -Configuration $pesterConfig
	}
}

task Pack {
    <#
    .SYNOPSIS
	Copy the relevant files to the specified output folder.
	#>
	if($null -eq $Folder) {
		Write-Error "Please specify the output folder parameter"
		return
	}

	Push-Location
	Set-Location "$PSScriptRoot"

	# Create the package directory
	if($null -eq $Folder) {
		$Folder = (Join-Path "package" "EnvironmentModuleCore")
	}

	if(Test-Path $Folder) {
		Remove-Item -Recurse -Force $Folder
	}

	New-Item -ItemType directory $Folder

	# Copy the relevant items to the package folder
	Copy-Item "*.ps*1" $Folder -Exclude "Tasks.build.ps1", "SetupEnvironment.ps1", "Tasks.build.ps1"
	Copy-Item "*.dll" $Folder
	Copy-Item "LICENSE.md" $Folder
	Copy-Item "*.ps1xml" $Folder
	Copy-Item "Templates" $Folder -Recurse
	Copy-Item "Extensions" $Folder -Recurse

	if(-not [string]::IsNullOrEmpty($Suffix)) {
		Update-ModuleManifest "$(Join-Path $Folder 'EnvironmentModuleCore.psd1')" -Prerelease "$Suffix"
	}
}

task Deploy {
    <#
    .SYNOPSIS
	Copy the relevant files to the specified output folder and publish it via nuget afterwards.
	#>
	Publish-Module -Path "$Folder" -Verbose -Repository $NugetSource -NuGetApiKey $NuGetApiKey
}