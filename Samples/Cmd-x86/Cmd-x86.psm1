# ------------------------
# Static header
# ------------------------

$MODULE_NAME = $MyInvocation.MyCommand.ScriptBlock.Module.Name

# ------------------------
# User content
# ------------------------

$MODULE_SEARCHPATHS = @("C:\Windows\system32\")
$MODULE_ROOT = Find-FirstFile "cmd.exe" "" $MODULE_SEARCHPATHS
$MODULE_DEPENDENCIES = @()

function SetModulePathsInternal([EnvironmentModules.EnvironmentModule] $eModule, [String] $eModuleRoot)
{
	$eModule.AddAlias("npp", "Start-Cmd", "Use 'cm' to start Cmd")
	$eModuleRoot = (Resolve-Path (Join-Path $eModuleRoot "..\"))
	
	return $eModule
}

New-EnvironmentModuleFunction "Start-Cmd" { & "$MODULE_ROOT" }

# ------------------------
# Static footer
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