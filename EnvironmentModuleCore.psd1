#
# Module manifest for module 'EnvironmentModuleCore'
#
# Generated by: Marcus Walther
#
# Generated on: 25/02/2019
#

@{

    # Script module or binary module file associated with this manifest
    RootModule = 'EnvironmentModuleCore.psm1'

    # Version number of this module.
    ModuleVersion = '3.6.0'
    #---
    PrivateData = @{
        PSData = @{
            ProjectUri = 'https://github.com/MarcusWalther/EnvironmentModuleCore'
            LicenseUri = 'https://github.com/MarcusWalther/EnvironmentModuleCore/blob/master/LICENSE'
            Tags = @('PowerShell', 'PSEdition_Core', 'PSEdition_Desktop', 'Environment', 'Modules', 'EnvironmentModules', 'Linux', 'Windows')
            Icon = 'https://raw.githubusercontent.com/MarcusWalther/EnvironmentModuleCoreSrc/master/IconMedium.png'
        }
    }

    # ID used to uniquely identify this module
    GUID = '8e0eb79a-6bcc-4214-9f73-4b021fd186fc'

    # Author of this module
    Author = 'Marcus Walther'

    # Copyright statement for this module
    Copyright = '(c) 2022 Marcus Walther'

    # Description of the functionality provided by this module
    Description = 'This module includes all core features to export environment modules. Environment modules are like Powershell-Modules, but they can modify environment variables on load and restore the old environment state on remove. The functionallity was inspired by the Linux program modulecmd.'

    # Minimum version of the Windows PowerShell host required by this module
    PowerShellVersion = '5.1'

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @("EnvironmentModuleCore.dll")

    # The Powershell Versions that are compatible with the module
    CompatiblePSEditions = @('Desktop', 'Core')

    # Functions to export from this module
    FunctionsToExport = @('Import-EnvironmentModule', 'Remove-EnvironmentModule', 'Get-EnvironmentModule',
                        'Test-EnvironmentModuleLoaded', 'Switch-EnvironmentModule', 'New-EnvironmentModule', 'New-EnvironmentModuleFunction', 'Edit-EnvironmentModule',
                        'Update-EnvironmentModuleCache', 'Copy-EnvironmentModule', 'Get-EnvironmentModuleFunction', 'Get-EnvironmentModuleAlias',
                        'New-EnvironmentModuleExecuteFunction', 'Invoke-EnvironmentModuleFunction', 'Add-EnvironmentModuleSearchPath', 'Remove-EnvironmentModuleSearchPath',
                        'Clear-EnvironmentModuleSearchPaths', 'Clear-EnvironmentModules', 'Test-EnvironmentModuleRootDirectory',
                        'Get-EnvironmentModuleSearchPath', 'Get-EnvironmentModulePath', 'Set-EnvironmentModuleConfigurationValue', 'Export-EnvironmentModuleCoreConfiguration',
                        'Import-EnvironmentModuleCoreConfiguration', 'Get-EnvironmentModuleParameter', 'Set-EnvironmentModuleParameter', 'Split-EnvironmentModuleName',
                        'Show-EnvironmentSummary', 'Read-EnvironmentModuleDescriptionFileByPath', 'Compare-EnvironmentModulesByVersion',
                        'Get-VirtualParameterEnvironments', 'Enable-VirtualParameterEnvironment')

    # Variables to export from this module
    VariablesToExport = @()

    # No nested modules should be considered
    NestedModules = @()

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # List of all files packaged with this module
    FileList = @('Configuration.ps1', 'DescriptionFile.ps1', 'Dismounting.ps1', 'EnvironmentModuleCore.ps1', 'EnvironmentModuleCore.psd1', 'EnvironmentModuleCore.psm1',
                 'ModuleCreation.ps1', 'ModuleParameters.ps1', 'Mounting.ps1', 'Storage.ps1', 'Utils.ps1', 'Types.ps1xml')

    # The type defintions for the type visualisation
    TypesToProcess=@('Types.ps1xml')
}

