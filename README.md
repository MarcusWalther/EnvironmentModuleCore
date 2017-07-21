# PS_EnvironmentModules
A powershell extension to load and remove modules that affect the environment variables of the running session.

Overview
--------

This PowerShell extension can be used to modify the environment variables and aliases of the active PowerShell-session. Therefore special modules 
are defined that are called "environment modules". Such an environment module defines a set of variables, aliases and functions that are added to the session when the module is loaded. These information will be available until the session is closed or the environment module is unloaded.

Example
-------

```powershell
Import-Module EnvironmentModules

Write-Host $env:PATH
# Output: 

Import-EnvironmentModule NotepadPlusPlus
Write-Host $env:PATH
# Output: C:\Program Files (x86)\Notepad++

# npp is alias to start Notepad++
npp

Remove-EnvironmentModule NotepadPlusPlus

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
- **Import-EnvironmentModule [ModuleName]**

Removing an evnironment module
- **Remove-EnvironmentModule [ModuleName]**

List all loaded mounted environment modules
- **Get-EnvironmentModule**


Environment-Module-Files
------------------------

```powershell
# ------------------------
# Static header - Do not touch
# ------------------------

$MODULE_NAME = $MyInvocation.MyCommand.ScriptBlock.Module.Name

# ------------------------
# User content
# ------------------------

$MODULE_ROOT = "C:\Program Files (x86)\Notepad++\notepad++.exe"
$MODULE_DEPENDENCIES = @("Aspell") #All other environment modules that should be loaded as dependencies

function SetModulePathsInternal([EnvironmentModules.EnvironmentModule] $eModule, [String] $eModuleRoot)
{
	$eModule.AddAlias("npp", "Start-NotepadPlusPlus", "Use 'npp' to start Notepad++")
	$eModuleRoot = (Resolve-Path (Join-Path $eModuleRoot "..\"))
	
	return $eModule
}

New-EnvironmentModuleFunction "Start-NotepadPlusPlus" { 	
	Start-Process -FilePath "$MODULE_ROOT" @args
}

# ------------------------
# Static footer - Do not touch
# ------------------------

function RemoveModulePathsInternal()
{
	[void](Dismount-EnvironmentModule -Name $MODULE_NAME)
}

$callStack = Get-PSCallStack | Select-Object -Property *
if(($callStack.Count -gt 1) -and (($callStack[($callStack.Count - 2)].FunctionName) -match "Import-EnvironmentModule")) {
  Mount-EnvironmentModule -Name $MODULE_NAME -Root $MODULE_ROOT -Info $MyInvocation.MyCommand.ScriptBlock.Module -CreationDelegate ${function:SetModulePathsInternal} -DeletionDelegate ${function:RemoveModulePathsInternal} -Dependencies $MODULE_DEPENDENCIES
}
else {
  Write-Host "The environment module was not loaded via 'Import-EnvironmentModule' - it is treated as simple PowerShell-module" -foregroundcolor "Yellow" 
}
```
