<#
    This file contains the 'unit tests' for the BuildFunctions.Release script. These tests are executed
    using Pester (https://github.com/pester/Pester).
#>

Describe 'Meta installation' {
    Context 'The meta install location' {
        It 'has the directories' {
            'c:\meta' | Should Exist
        }

        It 'has a valid metadata file' {
            $metaFile = 'c:\meta\meta.json'
            $metaFile | Should Exist
            { ConvertFrom-Json (Get-Content $metaFile) } | Should Not Throw
        }
    }
}
