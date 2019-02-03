# EnvironmentModules
A powershell extension to load and remove modules that affect the environment (variables, aliases and functions) of the running session. These features will make the Powershell more powerful when used interactively or in automatic processes.

Overview
--------

This PowerShell extension can be used to modify the environment variables and aliases of the active PowerShell-session. Therefore special modules
are defined that are called "environment modules". Such an environment module defines a set of variables, aliases and functions that are added to the session when the module is loaded. These information will be available until the session is closed or the environment module is unloaded.

Example
-------

```powershell
Import-Module EnvironmentModules

Write-Host $env:PATH
# Output:

Import-EnvironmentModule NotepadPlusPlus
Write-Host $env:PATH
# Output: C:\Program Files (x86)\Notepad++

# npp is alias to start Notepad++
npp

Remove-EnvironmentModule NotepadPlusPlus

Write-Host $env:PATH
# Output:

# Alias npp not available anymore
```

Installation
------------

The code is provided as PowerShell-Module. Download the files to a folder called "EnvironmentModules" and add the parent folder to the **PSModulePath** environment variable.


Usage
-----

Import the module to get access to the functions
- **Import-Module EnvironmentModules**

Import an environment module with the function
- **Import-EnvironmentModule [ModuleName]**

Remove a previously loaded evnironment module
- **Remove-EnvironmentModule [ModuleName]**

List all loaded mounted environment modules or display all available environment modules
- **Get-EnvironmentModule [-ListAvailable]**

Create a new environment module from skretch or from an existing module
- **New-EnvironmentModule [params]**
- **Copy-EnvironmentModule [params]**

Edit environment module file(s)
- **Edit-EnvironmentModule [ModuleName] [FileFilter]**

Update the cache
- **Update-EnvironmentModuleCache**

Environment-Module-Description-File (*.pse)
-------------------------------------------
Each environment module should contain a pse file in its module directory. The syntax of such a file is similar to the syntax of the psd files.

```powershell
@{
    # Environment Modules that must be imported into the global environment prior importing this module
    RequiredEnvironmentModules = @("Aspell")

    # The type of the module, either "Default" or "Meta" if it is a project-module
    ModuleType = "Default"

    # Default search paths in the registry
    DefaultRegistryPaths = @("HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++\DisplayIcon")

    # Default search paths on the file system
    DefaultFolderPaths = @("C:\Program Files (x86)\Notepad++")

    # Default environment variable search paths
    DefaultEnvironmentPaths = @("NOTEPAD_PLUS_PLUS_ROOT")

    # Required files that must be part of the folder candidate
    RequiredFiles = @("notepad++.exe")

    # The version of the description files
    StyleVersion = 2.1

    # Parameters that control the behaviour of the module. These values can be overwritten by other modules or the user
    Parameters = @{
        "NotepadPlusPlus.Parameter1" = "Value1"
        "NotepadPlusPlus.Parameter2" = "Value2"
    }
}
```

Environment-Module-Files (*.psm)
--------------------------------
The psm file of an environment module has a special module parameter as argument. This parameter can be used to manipulate the environment.

```powershell
param(
    [parameter(Position=0, Mandatory=$true)]
    [EnvironmentModules.EnvironmentModule]
    $Module
)

$Module.AddPrependPath("PATH", $Module.ModuleRoot)
$Module.AddAlias("npp", "Start-NotepadPlusPlus", "Use 'npp' to start NotepadPlusPlus")

[String] $cmd = "Start-Process -FilePath '$($Module.ModuleRoot)\notepad++.exe' @args"
$Module.AddFunction("Start-NotepadPlusPlus", [ScriptBlock]::Create($cmd))
```

Naming Convention
-----------------

The name of an environment module plays an important role, because it is used to identify conflicts and default modules. The name of an environment module can be:
 - EnvironmentModuleName -> A simple module name without dashes, indicating that the architecture and version doesn't matter (for instance *NotepadPlusPlus*)
 - EnvironmentModuleName-Version -> A module with a version number. The version parts are separated by underscores (for instance *NotepadPlusPlus-7_4_2*)
 - EnvironmentModuleName-Version-Architecture -> An additional version tag can be specified. Either 'x64' or 'x86' are supported at the moment (for instance *NotepadPlusPlus-7_4_2-x86*).
 - EnvironmentModuleName-Version-Architecture-AdditionalInformation -> Additional information can be specified at the end (for instance *NotepadPlusPlus-7_4_2-x86-DEV*).


Caching and Default Modules
---------------------------

In order to identify all available environment modules, the scripts will use 'Get-Module -ListAvailable'. It will identify all modules as environment module, that have a dependency to 'EnvironmentModules' in their '\*.psd1'. Because this is a time consuming process, a cache is used to store the information persistently. The caching infos are stored in the file 'ModuleCache.xml' and can be rebuild with the *Update-EnvironmentModuleCache* function. Besides that, this functionality will create default modules in the directory 'Tmp/Modules'.
