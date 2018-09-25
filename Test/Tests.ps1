if(Get-Module "EnvironmentModules") {
    Remove-Module "EnvironmentModules"
}

Import-Module "$PSScriptRoot\..\EnvironmentModules.psd1"

if((Get-Module -Name "Pester") -eq $null) {
    Import-Module Pester
}

. "$PSScriptRoot\..\Samples\StartSampleEnvironment.ps1"

Describe 'TestLoading' {

    It 'Main module was loaded' {
        $loadedModules = Get-Module | Select-Object -Expand Name
        'EnvironmentModules' | Should -BeIn $loadedModules
    }

    It 'Default Modules were created' {
        $availableModules = Get-EnvironmentModule -ListAvailable | Select-Object -Expand FullName
        'NotepadPlusPlus' | Should -BeIn $availableModules
    }

    It 'Abstract Default Module was not created' {
        $availableModules = Get-EnvironmentModule -ListAvailable | Select-Object -Expand FullName
        'Abstract' | Should -Not -BeIn $availableModules
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
    Add-EnvironmentModuleSearchPath -Module "Project-ProgramB" -Type "Directory" -Value $customDirectory

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
    Add-EnvironmentModuleSearchPath -Module "Project-ProgramB" -Type "Environment" -Value "TESTLADOING_PATH"

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

Describe 'TestLoading_InvalidCustomPath' {
    Clear-EnvironmentModuleSearchPaths -Force
    $customDirectory = Join-Path $PSScriptRoot "..\..\Samples\Project-ProgramB"
    Add-EnvironmentModuleSearchPath -Module "Project-ProgramB" -Type "Directory" -Value $customDirectory

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
    Import-EnvironmentModule 'Cmd'
    Import-EnvironmentModule 'Project-ProgramA'

    $knownFunctions = Get-EnvironmentModuleFunctions "Start-Cmd"

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
        
        $result = Invoke-EnvironmentModuleFunction "Start-Cmd" "Cmd" -ArgumentList "/C echo 45"
        $result | Should -Not -BeNullOrEmpty $result.Id  
    }

    Remove-EnvironmentModule 'Cmd'
    Remove-EnvironmentModule 'Project-ProgramA'
}

#Get-EnvironmentModuleFunction -Name "Start-Cmd" -OverwrittenBy $MODULE_NAME