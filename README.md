# PS_EnvironmentModules
A powershell extension to load and remove modules that affect the environment variables of the running session.

Overview
--------

This PowerShell extension can be used to modify the environment variables and aliases of the active PowerShell-session. Therefore special modules 
are defined that are called "environment modules". Such an environment module defines a set of variables, aliases and functions that are added to 
the session when the module is mounted.

Example
-------

```powershell
Import-Module EnvironmentModules

Write-Host $env:PATH
# Output: 

Mount-EnvironmentModule NotepadPlusPlus
Write-Host $env:PATH
# Output: C:\Program Files (x86)\Notepad++

# npp is alias to start Notepad++
npp

Dismount-EnvironmentModule NotepadPlusPlus

Write-Host $env:PATH
# Output: 

# Alias npp not available anymore
```

Installation
------------

The code is provided as PowerShell-Module. Download the files and add the EnvironmentModules folder to the **PSModulePath** environment variable. 


Usage
-----

Import the module to get access to the functions
- **Import-Module EnvironmentModules**

Import an environment module with the function
- **Mount-EnvironmentModule [ModuleName]**

Removing an evnironment module
- **Dismount-EnvironmentModule [ModuleName]**

List all loaded mounted environment modules
- **Get-EnvironmentModule**


Environment-Module-Files
------------------------

```powershell
# ------------------------
# Static header
# ------------------------

$MODULE_NAME = $MyInvocation.MyCommand.ScriptBlock.Module.Name

# ------------------------
# User content
# ------------------------

$MODULE_SEARCHPATHS = @("C:\Program Files (x86)\Notepad++\")
$MODULE_ROOT = Find-FirstFile "notepad++.exe" "" $MODULE_SEARCHPATHS

function SetModulePathsInternal([EnvironmentModules.EnvironmentModule] $eModule, [String] $eModuleRoot)
{
	$eModule.AddAlias("npp", "Start-NotepadPlusPlus", "Use 'npp' to start Notepad++")
	$eModuleRoot = (Resolve-Path (Join-Path $eModuleRoot "..\"))
	
	return $eModule
}

New-EnvironmentModuleFunction "Start-NotepadPlusPlus" { & "$MODULE_ROOT" }

# ------------------------
# Static footer
# ------------------------

function RemoveModulePathsInternal()
{
	[void](Dismount-EnvironmentModule -Name $MODULE_NAME)
}

Mount-EnvironmentModule -Name $MODULE_NAME -Root $MODULE_ROOT -Info $MyInvocation.MyCommand.ScriptBlock.Module -CreationDelegate ${function:SetModulePathsInternal} -DeletionDelegate ${function:RemoveModulePathsInternal}
```
