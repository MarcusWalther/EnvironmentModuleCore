param(
    [parameter(Position=0, Mandatory=$true)]
	[EnvironmentModuleCore.EnvironmentModule]
	$Module
)

$Module.AddSetPath("PROJECT_ROOT", "C:\Temp")

$Module.AddFunction("Start-Cmd", {
	return $args
})