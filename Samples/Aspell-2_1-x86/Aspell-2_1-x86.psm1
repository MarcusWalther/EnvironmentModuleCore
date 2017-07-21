# ------------------------
# Static header
# ------------------------

$MODULE_NAME = $MyInvocation.MyCommand.ScriptBlock.Module.Name

# ------------------------
# User content
# ------------------------

$MODULE_SEARCHPATHS = @("C:\Program Files (x86)\Aspell")
$MODULE_ROOT = (Find-FirstFile "aspell.exe" "bin" $MODULE_SEARCHPATHS)
$MODULE_DEPENDENCIES = @()

function SetModulePathsInternal([EnvironmentModules.EnvironmentModule] $eModule, [String] $eModuleRoot)
{
	$eModuleRoot = (Resolve-Path (Join-Path $eModuleRoot "..\"))
	$eModule.AddPrependPath("PATH", $eModuleRoot)
	
	return $eModule
}

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