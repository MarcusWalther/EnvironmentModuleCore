# ------------------------
# Static header
# ------------------------

$MODULE_NAME = $MyInvocation.MyCommand.ScriptBlock.Module.Name

# ------------------------
# User content
# ------------------------

$MODULE_ROOT = ".\"

function SetModulePathsInternal([EnvironmentModules.EnvironmentModule] $eModule, [String] $eModuleRoot)
{	
    $eModule.ModuleType = [EnvironmentModules.EnvironmentModuleType]::Meta
    return $eModule
}

# ------------------------
# Static footer
# ------------------------

Mount-EnvironmentModule -Name $MODULE_NAME -Root $MODULE_ROOT -Info $MyInvocation.MyCommand.ScriptBlock.Module -CreationDelegate ${function:SetModulePathsInternal} -DeletionDelegate ${Dismount-EnvironmentModule @args}