param(
    [parameter(Position=0, Mandatory=$true)]
	[EnvironmentModules.EnvironmentModule]
	$Module
)

$Module.AddPrependPath("PATH", $Module.ModuleRoot)
$Module.AddFunction("Start-Cmd", {
	Start-Process -FilePath "$Module.ModuleRoot\cmd.exe" @args
})

[String] $cmd = "Start-Process -FilePath '$($Module.ModuleRoot)\cmd.exe' @args"
$Module.AddFunction("Start-Cmd", [ScriptBlock]::Create($cmd))