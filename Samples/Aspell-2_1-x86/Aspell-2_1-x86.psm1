param(
    [parameter(Position=0, Mandatory=$true)]
	[EnvironmentModules.EnvironmentModule]
	$Module
)

# # ------------------------
# # Static header
# # ------------------------

# $MODULE_NAME = $MyInvocation.MyCommand.ScriptBlock.Module.Name

# # ------------------------
# # User content
# # ------------------------

# $MODULE_SEARCHPATHS = @("C:\Program Files (x86)\Aspell")
# $MODULE_ROOT = (Find-FirstFile "aspell.exe" "bin" $MODULE_SEARCHPATHS)

# function SetModulePathsInternal([EnvironmentModules.EnvironmentModule] $eModule, [String] $eModuleRoot)
# {
# 	$eModuleRoot = (Resolve-Path (Join-Path $eModuleRoot "..\"))
# 	$eModule.AddPrependPath("PATH", $eModuleRoot)
	
# 	return $eModule
# }

# # ------------------------
# # Static footer
# # ------------------------

# Mount-EnvironmentModule -Name $MODULE_NAME -Root $MODULE_ROOT -Info $MyInvocation.MyCommand.ScriptBlock.Module -CreationDelegate ${function:SetModulePathsInternal} -DeletionDelegate ${Dismount-EnvironmentModule @args}