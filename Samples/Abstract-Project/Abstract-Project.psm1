param(
    [parameter(Position=0, Mandatory=$true)]
	[EnvironmentModules.EnvironmentModule]
	$Module
)

$Module.AddFunction("Get-ProjectRoot", {
	return $env:PROJECT_ROOT
})