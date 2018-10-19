if($null -eq (Get-Module -Name "Pester")) {
    Import-Module Pester
}

. "$PSScriptRoot\..\Samples\StartSampleEnvironment.ps1"

Describe 'TestLoading' {

    It 'Main module was loaded' {
        $loadedModules = Get-Module | Select-Object -Expand Name
        'EnvironmentModules' | Should -BeIn $loadedModules
    }

    It 'Default Modules were created' {
        $availableModules = Get-EnvironmentModule -ListAvailable -ModuleFullName "NotepadPlusPlus"
        $availableModules.Length | Should -Be 1
    }

    It 'Abstract Default Module was not created' {
        $availableModules = Get-EnvironmentModule -ListAvailable -ModuleFullName "Abstract"
        $availableModules | Should -Be $null
    }    

    It 'Meta Default Module was not created' {
        $availableModules = Get-EnvironmentModule -ListAvailable | Select-Object -Expand FullName
        'Project' | Should -Not -BeIn $availableModules
    }        

    Import-EnvironmentModule 'NotepadPlusPlus'

    It 'Meta-Module is unloaded directly' {
        $metaModule = Get-EnvironmentModule | Where-Object -Property "FullName" -eq "NotepadPlusPlus"
        $metaModule | Should -BeNullOrEmpty
    }

    It 'Module is loaded correctly' {
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -eq "NotepadPlusPlus-x64"
        $module | Should -Not -BeNullOrEmpty
    }

    It 'Dependency was loaded correctly' {
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -eq "Aspell-2_1-x86"
        $module | Should -Not -BeNullOrEmpty
    }

    Remove-EnvironmentModule 'NotepadPlusPlus-x64'

    It 'Module can be removed with dependencies' {
        $module = Get-EnvironmentModule
        $module | Should -BeNullOrEmpty   
    }   
}

Describe 'TestLoading_CustomPath_Directory' {
    Clear-EnvironmentModuleSearchPaths -Force
    $customDirectory = Join-Path $PSScriptRoot "..\Samples\Project-ProgramB"
    Add-EnvironmentModuleSearchPath "Project-ProgramB" "Directory" $customDirectory

    Import-EnvironmentModule "Project-ProgramB"
    It 'Module is loaded correctly' {
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -eq "Project-ProgramB"
        $module | Should -Not -BeNullOrEmpty
    }

    Remove-EnvironmentModule 'Project-ProgramB'

    It 'Module can be removed with dependencies' {
        $module = Get-EnvironmentModule
        $module | Should -BeNullOrEmpty   
    }       
}

Describe 'TestLoading_CustomPath_Environment' {
    Clear-EnvironmentModuleSearchPaths -Force
    $customDirectory = Join-Path $PSScriptRoot "..\Samples\Project-ProgramB"
    $env:TESTLADOING_PATH = "$customDirectory"
    Add-EnvironmentModuleSearchPath -ModuleFullName "Project-ProgramB" -Type "Environment" -Key "TESTLADOING_PATH"
    Add-EnvironmentModuleSearchPath -ModuleFullName "Project-ProgramB" -Type "Environment" -Key "UNDEFINED_VARIABLE"

    Import-EnvironmentModule "Project-ProgramB"
    It 'Module is loaded correctly' {
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -eq "Project-ProgramB"
        $module | Should -Not -BeNullOrEmpty
    }

    $searchPaths = Get-EnvironmentModuleSearchPath "Project-ProgramB"

    It 'SearchPath correctly returned' {
        $searchPaths.Count | Should -Be 2
        $searchPaths[0].Key | Should -Be "TESTLADOING_PATH"
    } 

    It 'Remove Search Path works correctly' {
        # Remove-EnvironmentModuleSearchPath -ModuleFullName "Project-ProgramB" #For Manual Testing
        Remove-EnvironmentModuleSearchPath -ModuleFullName "Project-ProgramB" -Key "UNDEFINED_VARIABLE"
        $searchPaths = Get-EnvironmentModuleSearchPath "Project-ProgramB"
        $searchPaths.Count | Should -Be 1
    }     

    Remove-EnvironmentModule 'Project-ProgramB'

    It 'Module can be removed with dependencies' {
        $module = Get-EnvironmentModule
        $module | Should -BeNullOrEmpty   
    }       
}

Describe 'TestLoading_Environment_Subpath' {
    Clear-EnvironmentModuleSearchPaths -Force
    $customDirectory = Join-Path $PSScriptRoot "..\Samples\Project-ProgramC"
    $env:PROJECT_PROGRAM_C_ROOT = "$customDirectory"

    Import-EnvironmentModule "Project-ProgramC"
    It 'Module is loaded correctly with sub-path' {
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -eq "Project-ProgramC"
        $module | Should -Not -BeNullOrEmpty
    }

    Remove-EnvironmentModule 'Project-ProgramC'

    It 'Module can be removed with dependencies' {
        $module = Get-EnvironmentModule
        $module | Should -BeNullOrEmpty   
    }       
}

Describe 'TestLoading_InvalidCustomPath' {
    Clear-EnvironmentModuleSearchPaths -Force
    $customDirectory = Join-Path $PSScriptRoot "..\..\Samples\Project-ProgramB"
    Add-EnvironmentModuleSearchPath -ModuleFullName "Project-ProgramB" -Type "Directory" -Key $customDirectory

    Import-EnvironmentModule "Project-ProgramB"
    It 'Module should not be loaded because of invalid root path' {
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -eq "Project-ProgramB"
        $module | Should -BeNullOrEmpty
    }    
}

Describe 'TestLoading_AbstractModule' {
    try {
        Import-EnvironmentModule 'Abstract-Project'
    }
    catch {

    }

    It 'Modules was not loaded' {   
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -like "Abstract-Project" 
        $module | Should -BeNullOrEmpty 
    }
    
    Import-EnvironmentModule "Project-ProgramA"
    It 'Module is loaded correctly' {
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -eq "Project-ProgramA"
        $module | Should -Not -BeNullOrEmpty
    }

    It 'Abstract Module is loaded correctly' {
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -eq "Abstract-Project"
        $module | Should -Not -BeNullOrEmpty
    }   

    It 'Abstract Module Functions are available' {
        $result = Get-ProjectRoot  # Call function of abstract module
        $result | Should -BeExactly "C:\Temp"
    }       

    Remove-EnvironmentModule 'Project-ProgramA'

    It 'Module can be removed with dependencies' {
        $module = Get-EnvironmentModule
        $module | Should -BeNullOrEmpty   
    }   

}

Describe 'TestCopy' {
    It 'Modules was correctly copied and deleted afterwards' {   
        $module = Get-EnvironmentModule -ListAvailable "Project-ProgramA"
        $module | Should -Not -BeNullOrEmpty 
        Copy-EnvironmentModule Project-ProgramA "Project-ProgramACopy" (Resolve-Path (Join-Path $module.ModuleBase '..\'))
        $newModule = Get-EnvironmentModule -ListAvailable "Project-ProgramACopy"
        $newModule | Should -Not -BeNullOrEmpty

        $files = Get-ChildItem "$($newModule.ModuleBase)" | Select-Object -ExpandProperty "Name"
        $files | Should -Contain "ProjectRelevantFile.txt"
        
        Remove-EnvironmentModule -Delete -Force "Project-ProgramACopy"

        $newModule = Get-EnvironmentModule -ListAvailable "Project-ProgramACopy"
        $newModule | Should -BeNullOrEmpty
    }
}

Describe 'TestSwitch' {
    Import-EnvironmentModule 'Project-ProgramA'

    It 'Modules were loaded correctly' {   
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -like "NotepadPlusPlus-x86" 
        $module | Should -Not -BeNullOrEmpty 

        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -like "Cmd*" 
        $module | Should -Not -BeNullOrEmpty 
    }

    It 'Switch module works' {
        Switch-EnvironmentModule 'NotepadPlusPlus-x86' 'NotepadPlusPlus-x64'
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -like "NotepadPlusPlus-x86" 
        $module | Should -BeNullOrEmpty 

        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -like "NotepadPlusPlus-x64" 
        $module | Should -Not -BeNullOrEmpty         
    }

    It 'Meta function works' {
        $result = Start-Cmd 42
        $result | Should -BeExactly 42
    }

    Remove-EnvironmentModule 'Project-ProgramA'

    It 'Meta Module can be removed with dependencies' {
        $module = Get-EnvironmentModule
        $module | Should -BeNullOrEmpty   
    }
}

Describe 'TestGet' {
    Import-EnvironmentModule 'Project-ProgramA'

    It 'Correct style version is returned' {
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -like "Project-ProgramA" 
        ($module.StyleVersion) | Should -Be 2
    }

    Remove-EnvironmentModule 'Project-ProgramA'
}

Describe 'TestFunctionStack' {
    Import-EnvironmentModule 'Project-ProgramA'

    $knownFunctions = Get-EnvironmentModuleFunctionModules "Start-Cmd"

    It 'Function Stack has correct structure' {
        $knownFunctions | Should -HaveCount 2

        $knownFunctions[0] | Should -Be "Cmd"
        $knownFunctions[1] | Should -Be "Project-ProgramA"
    }

    It 'Function Stack invoke does work correctly' {
        $result = Invoke-EnvironmentModuleFunction "Start-Cmd" "Project-ProgramA" -ArgumentList "42"
        $result | Should -Be 42

        $result = Start-Cmd "42"
        $result | Should -Be 42     
        
        $result = Invoke-EnvironmentModuleFunction "Start-Cmd" "Cmd" -ArgumentList '/C "echo 45"'
        $result | Should -Be 45 
    }

    Remove-EnvironmentModule 'Project-ProgramA'
}