param(
    [parameter(Position=0, Mandatory=$true)]
	[EnvironmentModules.EnvironmentModule]
	$Module
)

$Module.AddPrependPath("PATH", $Module.ModuleRoot)