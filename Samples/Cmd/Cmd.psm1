param(
    [parameter(Position=0, Mandatory=$true)]
	[EnvironmentModuleCore.EnvironmentModule]
	$Module
)

$Module.AddPrependPath("PATH", $Module.ModuleRoot)
$Module.AddFunction("Start-Cmd", {
	$pinfo = New-Object System.Diagnostics.ProcessStartInfo
	$pinfo.FileName = "cmd.exe"
	$pinfo.RedirectStandardError = $true
	$pinfo.RedirectStandardOutput = $true
	$pinfo.UseShellExecute = $false
	$pinfo.Arguments = $args
	$p = New-Object System.Diagnostics.Process
	$p.StartInfo = $pinfo
	$p.Start() | Out-Null
	$p.WaitForExit()
	return $p.StandardOutput.ReadToEnd()
})