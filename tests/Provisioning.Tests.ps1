<#
    This file contains the 'verification tests' for the 'consul' section of the ops_resource_core cookbook. These tests are executed
    using Pester (https://github.com/pester/Pester).
#>

Describe 'Provisioning installation:' {

    Context 'The install location' {
        It 'has the directories' {
            'c:\ops' | Should Exist
            'c:\ops\provisioning' | Should Exist
            'c:\ops\provisioning\service' | Should Exist
        }

        It 'has the Provisioning binaries' {
            'c:\ops\provisioning\service\provisioning_service.exe' | Should Exist
            'c:\ops\provisioning\service\provisioning_service.xml' | Should Exist
            'c:\ops\provisioning\service\provisioning_service.exe.config' | Should Exist
            'c:\ops\provisioning\service\Initialize-Resource.ps1' | Should Exist
        }
    }

    Context 'The logs location' {
        It 'has the directories' {
            'c:\logs' | Should Exist
            'c:\logs\provisioning' | Should Exist
        }
    }

    Context 'The consul service' {
        $service = Get-WmiObject win32_service | Where {$_.name -eq 'provisioning'} | Select -First 1
        It 'is running as LocalSystem' {
            $service | Should Not BeNullOrEmpty
            $service.StartName | Should Be 'LocalSystem'
        }

        It 'has been disabled' {
            $service.StartMode | Should Be 'Disabled'
        }
    }
}
