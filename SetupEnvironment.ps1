# This script installs the required Powershell packages.
# It is mainly used by the Azure Pipeline. Copied from https://github.com/Jaykul/PTUI/blob/master/RequiredModules.psd1.

using namespace Microsoft.PowerShell.Commands
[CmdletBinding()]
param(
    [ValidateSet("CurrentUser", "AllUsers")]
    $Scope = "CurrentUser"
)

[ModuleSpecification[]] $RequiredModules = @([Microsoft.PowerShell.Commands.ModuleSpecification]::new("InvokeBuild"),
                                             [Microsoft.PowerShell.Commands.ModuleSpecification]::new("Pester"),
                                             [Microsoft.PowerShell.Commands.ModuleSpecification]::new("PSScriptAnalyzer"))
$Policy = (Get-PSRepository PSGallery).InstallationPolicy
Set-PSRepository PSGallery -InstallationPolicy Trusted

try {
    $RequiredModules | Install-Module -Scope $Scope -Repository PSGallery -SkipPublisherCheck -Verbose
} finally {
    Set-PSRepository PSGallery -InstallationPolicy $Policy
}

$RequiredModules | Import-Module