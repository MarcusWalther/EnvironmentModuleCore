<p align="center">
  <img src="https://github.com/MarcusWalther/EnvironmentModuleCoreSrc/blob/master/Icon.png?raw=true" height="64">
  <h3 align="center">EnvironmentModuleCore</h3>
  <p align="left">This PowerShell module can be used to modify the environment variables and aliases of the active PowerShell-session. Therefore special modules are defined that are called "Environment Modules". Such an environment module defines a set of variables, aliases and functions that are added to the session when the module is loaded. These information will be available until the session is closed or the environment module is unloaded.<p>
  <p align="center">
    <a href="">
      <img src="https://dev.azure.com/MarcusWalther/EnvironmentModuleCore/_apis/build/status/Master.EnvironmentModuleCore?branchName=master" alt="Azure Pipeline">
    </a>
    <a href="">
      <img alt="Azure DevOps tests" src="https://img.shields.io/azure-devops/tests/MarcusWalther/EnvironmentModuleCore/7">
    </a>
    <a href="https://www.powershellgallery.com/packages/EnvironmentModuleCore">
      <img src="https://img.shields.io/powershellgallery/vpre/EnvironmentModuleCore.svg" alt="Powershell Gallery Package">
    </a>
    <a href="https://github.com/MarcusWalther/EnvironmentModuleCore/blob/master/LICENSE.md">
      <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="MIT License">
    </a>
</p>

# Example

<p align="center">
<img src="https://github.com/MarcusWalther/EnvironmentModuleCore/blob/master/Samples/PythonScreen.gif">
</p>

# Installation

You can either download the package from the Powershell Gallery or downlaod it manually.
* **A)** Download the package from the Powershell Gallery using **Install-Module EnvironmentModuleCore**

* B) Download the files to a folder called "EnvironmentModuleCore" and add the parent folder to the **PSModulePath** environment variable. Execute the command below in order to download the required .Net core libraries.
```powershell
# Requires the module InvokeBuild (https://github.com/nightroman/Invoke-Build)
Invoke-Build Prepare
```

# Usage Overview

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

Update the cache (required if a new environment module was added)
- **Update-EnvironmentModuleCache**

Import the environment module dependencies from a pse1 file
- **Import-EnvironmentModuleDescriptionFile [FilePath]**

# Environment-Module-Description-File (*.pse)

Each environment module should contain a pse file in its module directory. The syntax of such a file is similar to the syntax of the psd files.

```powershell
@{
    # Environment Modules that must be imported into the global environment prior importing this module
    RequiredEnvironmentModules = @("Aspell")

    # Default search paths
    DefaultSearchPaths = @(@{Type="ENVIRONMENT_VARIABLE";Key="NOTEPAD_PLUS_PLUS_ROOT"}, "C:\Program Files (x86)\Notepad++",
                           @{Type="REGISTRY";Key="HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++\DisplayIcon"})

    # Required files that must be part of the folder candidate
    RequiredItems = @("notepad++.exe")

    # Parameters that control the behaviour of the module. These values can be overwritten by other modules or the user
    Parameters = @{
        "NotepadPlusPlus.Parameter1" = "Value1";
        "NotepadPlusPlus.Parameter2" = "Value2"
    }
}
```

# Environment-Module-Files (*.psm)

The psm file of an environment module has a special module parameter as argument. This parameter can be used to manipulate the environment.

```powershell
param(
    [parameter(Position=0, Mandatory=$true)]
    [EnvironmentModuleCore.EnvironmentModule]
    $Module
)

$Module.AddPrependPath("PATH", $Module.ModuleRoot)
$Module.AddAlias("npp", "Start-NotepadPlusPlus", "Use 'npp' to start NotepadPlusPlus")

[String] $cmd = "Start-Process -FilePath '$($Module.ModuleRoot)\notepad++.exe' @args"
$Module.AddFunction("Start-NotepadPlusPlus", [ScriptBlock]::Create($cmd))
```

# Testing 

Pester based tests are included as submodule that must be checked out explicitely. Afterwards the tests can be invoked using the command 

```powershell
# Requires the module InvokeBuild (https://github.com/nightroman/Invoke-Build)
Invoke-Build Test
```

# Documentation

A more detailed documentation is given in the [Github wiki](https://github.com/MarcusWalther/EnvironmentModuleCore/wiki).

# References

* Library -- Scriban (see https://github.com/lunet-io/scriban) - BSD 2-Clause "Simplified" License.
* Powershell Module -- InvokeBuild (see https://github.com/nightroman/Invoke-Build) - Apache License, Version 2.0
* Powershell Module -- Pester (see https://github.com/pester/Pester) - Apache License, Version 2.0
* Idea -- Environment Modules on Linux Systems (see http://modules.sourceforge.net)
* Icon -- Adaption of Powershell Icon (see https://de.wikipedia.org/wiki/Datei:PowerShell_5.0_icon.png)
