param(
    [parameter(Position=0, Mandatory=$true)]
	[EnvironmentModules.EnvironmentModule]
	$Module
)

$Module.AddFunction("Start-Cmd", {
	return $args;
})