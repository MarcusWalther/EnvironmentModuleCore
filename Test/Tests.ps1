if(Get-Module "EnvironmentModules") {
    Remove-Module "EnvironmentModules"
}

Import-Module "$PSScriptRoot\..\EnvironmentModules.psm1"

. "$PSScriptRoot\..\Samples\StartSampleEnvironment.ps1"

Describe 'TestLoading' {

    It 'Main module was loaded' {
        $loadedModules = Get-Module | Select-Object -Expand Name
        'EnvironmentModules' | Should -BeIn $loadedModules
    }

    It 'Default Modules were created' {
        $availableModules = Get-EnvironmentModule -ListAvailable | Select-Object -Expand Name
        'NotepadPlusPlus' | Should -BeIn $availableModules
    }  
    
    Import-EnvironmentModule 'NotepadPlusPlus'

    It 'Meta-Module is unloaded directly' {
        $metaModule = Get-EnvironmentModule | Where-Object -Property "FullName" -eq "NotepadPlusPlus"
        $metaModule | Should -BeNullOrEmpty
    }

    It 'Module is loaded correctly' {
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -eq "NotepadPlusPlus-x86"
        $module | Should -Not -BeNullOrEmpty        
    }

    It 'Dependency was loaded correctly' {
        $module = Get-EnvironmentModule | Where-Object -Property "FullName" -eq "Aspell-2_1-x86"
        $module | Should -Not -BeNullOrEmpty       
    }

    Remove-EnvironmentModule 'NotepadPlusPlus-x86'   

    It 'Module can be removed with dependencies' {
        $module = Get-EnvironmentModule #| Where-Object -Property "FullName" -eq "Aspell-2_1-x86"   
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
        ($module.StyleVersion) | Should -Be 0
    }

    Remove-EnvironmentModule 'Project-ProgramA'
}

Describe 'TestFunctionStack' {
    Import-EnvironmentModule 'Cmd'
    Import-EnvironmentModule 'Project-ProgramA'

    $knownFunctions = Get-EnvironmentModuleFunctions "Start-Cmd"

    $knownFunctions | Should -HaveCount 2

    $knownFunctions[0] | Should -Be "Cmd"
    $knownFunctions[1] | Should -Be "Project-ProgramA"

    $result = Invoke-EnvironmentModuleFunction "Start-Cmd" "Cmd"

    Remove-EnvironmentModule 'Cmd'
    Remove-EnvironmentModule 'Project-ProgramA'
}

#Get-EnvironmentModuleFunction -Name "Start-Cmd" -OverwrittenBy $MODULE_NAME