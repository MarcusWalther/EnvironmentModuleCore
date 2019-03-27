param(
    [parameter(Position=0, Mandatory=$true)]
	[EnvironmentModuleCore.EnvironmentModule]
	$Module
)

$Module.AddPrependPath("PATH", (Join-Path $Module.SourceModule.ModuleRoot "Scripts"))
$Module.AddPrependPath("PATH", $Module.SourceModule.ModuleRoot)

$Module.AddAlias("py", "Start-Python", "Use 'py' to start the Python interpreter")

$Module.AddFunction("Start-Python", {
	Start-Process -NoNewWindow -Wait -FilePath 'python.exe' @args
})