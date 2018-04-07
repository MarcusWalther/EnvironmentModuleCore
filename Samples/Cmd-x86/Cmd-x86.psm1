# ------------------------
# Static header
# ------------------------

$MODULE_NAME = $MyInvocation.MyCommand.ScriptBlock.Module.Name

# ------------------------
# User content
# ------------------------

$MODULE_SEARCHPATHS = @("C:\Windows\system32\")
$MODULE_ROOT = Find-FirstFile "cmd.exe" "" $MODULE_SEARCHPATHS

function SetModulePathsInternal([EnvironmentModules.EnvironmentModule] $eModule, [String] $eModuleRoot)
{
	$eModule.AddAlias("cm", "Start-Cmd", "Use 'cm' to start Cmd")
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

Mount-EnvironmentModule -Name $MODULE_NAME -Root $MODULE_ROOT -Info $MyInvocation.MyCommand.ScriptBlock.Module -CreationDelegate ${function:SetModulePathsInternal} -DeletionDelegate ${function:RemoveModulePathsInternal} -Dependencies $MODULE_DEPENDENCIES