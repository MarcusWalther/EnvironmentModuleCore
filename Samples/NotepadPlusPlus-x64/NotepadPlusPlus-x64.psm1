param(
    [parameter(Position=0, Mandatory=$true)]
	[EnvironmentModules.EnvironmentModule]
	$Module
)

$Module.AddPrependPath("PATH", $Module.ModuleRoot)
$Module.AddAlias("npp", "Start-NotepadPlusPlus", "Use 'npp' to start NotepadPlusPlus")

[String] $cmd = "Start-Process -FilePath '$($Module.ModuleRoot)\notepad++.exe' @args"
$Module.AddFunction("Start-NotepadPlusPlus", [ScriptBlock]::Create($cmd))