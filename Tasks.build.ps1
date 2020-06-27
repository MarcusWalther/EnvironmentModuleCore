param(
	[System.IO.DirectoryInfo] $Folder,
	[string] $NugetSource = "nuget.org",
	[string] $PowershellExecutable = "pwsh",
	[string] $Suffix = $null,
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

	if ((Get-ChildItem "Test").count -eq 0) {
		Write-Warning "The test folder submodule was not checked out correctly"
		return
	}

	New-Item -ItemType Directory "TestResults" -Force | Out-Null
	& "$PowershellExecutable" -NoProfile -Command {Import-Module "./EnvironmentModuleCore.psd1"; Set-Location "Test"; Invoke-Pester -Path "./Tests.ps1" -CI; Move-Item "*.xml" "../TestResults/"}
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
		Update-ModuleManifest "$Folder/EnvironmentModuleCore.psd1" -Prerelease "$Suffix"
	}
	$commandBlock = "& {Import-Module `"./$Folder/EnvironmentModuleCore.psd1`"; Set-Location `"Test`"; Invoke-Pester -Path `"./ScriptAnalyzerTests.ps1`" -CI; Move-Item `"testResults.xml`" `"../TestResults/testResults.analyzer.xml`"}"
	& "$PowershellExecutable" -NoProfile -Command $commandBlock
}

task Deploy {
    <#
    .SYNOPSIS
	Copy the relevant files to the specified output folder and publish it via nuget afterwards.
	#>

	$cmdArguments = "-Path '$Folder' -Repository $NugetSource -Verbose"

	if($AllowPrerelease) {
		$cmdArguments += " -AllowPrerelease"
	}

	if(-not [string]::IsNullOrEmpty($NuGetApiKey)) {
		$cmdArguments += " -NuGetApiKey $NuGetApiKey"
	}

    Publish-Module $cmdArguments  
}