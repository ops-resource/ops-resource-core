<#
    This file contains the 'verification tests' for the 'meta' section of the ops_resource_core cookbook. These tests are executed
    using Pester (https://github.com/pester/Pester).
#>

Describe 'Meta installation' {
    Context 'The meta install location' {
        It 'has the directories' {
            'c:\logs' | Should Exist
            'c:\meta' | Should Exist
            'c:\ops' | Should Exist
        }

        It 'has a valid metadata file' {
            $metaFile = 'c:\meta\meta.json'
            $metaFile | Should Exist
            { Get-Content $metaFile | Out-String | ConvertFrom-Json } | Should Not Throw
        }
    }
}
